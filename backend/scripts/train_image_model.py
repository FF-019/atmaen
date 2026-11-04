"""
Train the product image classifier (category level).

Dataset layout, one folder per protocol category:

    dataset/
      corrosive/        *.jpg
      detergent_pod/
      detergent_mild/
      hydrocarbon/
      medication/
      pesticide/
      alcohol/
      essential_oil/
      low_toxicity/
      button_battery/

We collected ~120-250 photos per class (phone camera, different lighting,
front + back of the bottle). MobileNetV2 is small enough to also export to
TFLite later for on-device inference.

    pip install -r requirements-ml.txt
    python -m scripts.train_image_model --data ./dataset --epochs 15
"""

import argparse
import json
from pathlib import Path

IMG = 224


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", required=True)
    ap.add_argument("--out", default="models_store/chemical_classifier.keras")
    ap.add_argument("--epochs", type=int, default=15)
    ap.add_argument("--fine-tune-epochs", type=int, default=5)
    ap.add_argument("--batch", type=int, default=32)
    ap.add_argument("--tflite", action="store_true", help="also export a .tflite next to the model")
    args = ap.parse_args()

    import tensorflow as tf

    train = tf.keras.utils.image_dataset_from_directory(
        args.data, validation_split=0.2, subset="training", seed=42,
        image_size=(IMG, IMG), batch_size=args.batch,
    )
    val = tf.keras.utils.image_dataset_from_directory(
        args.data, validation_split=0.2, subset="validation", seed=42,
        image_size=(IMG, IMG), batch_size=args.batch,
    )
    labels = train.class_names
    print("classes:", labels)

    autotune = tf.data.AUTOTUNE
    train = train.cache().shuffle(1000).prefetch(autotune)
    val = val.cache().prefetch(autotune)

    augment = tf.keras.Sequential([
        tf.keras.layers.RandomFlip("horizontal"),
        tf.keras.layers.RandomRotation(0.08),
        tf.keras.layers.RandomZoom(0.15),
        tf.keras.layers.RandomContrast(0.2),
    ])

    base = tf.keras.applications.MobileNetV2(input_shape=(IMG, IMG, 3), include_top=False, weights="imagenet")
    base.trainable = False

    inputs = tf.keras.Input(shape=(IMG, IMG, 3))
    x = augment(inputs)
    x = tf.keras.applications.mobilenet_v2.preprocess_input(x)
    x = base(x, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.3)(x)
    outputs = tf.keras.layers.Dense(len(labels), activation="softmax")(x)
    model = tf.keras.Model(inputs, outputs)

    model.compile(
        optimizer=tf.keras.optimizers.Adam(1e-3),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    stop = tf.keras.callbacks.EarlyStopping(patience=4, restore_best_weights=True)
    model.fit(train, validation_data=val, epochs=args.epochs, callbacks=[stop])

    # unfreeze the top of mobilenet and train a bit more with a small lr
    base.trainable = True
    for layer in base.layers[:-30]:
        layer.trainable = False
    model.compile(
        optimizer=tf.keras.optimizers.Adam(1e-5),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    model.fit(train, validation_data=val, epochs=args.fine_tune_epochs, callbacks=[stop])

    loss, acc = model.evaluate(val)
    print(f"validation accuracy: {acc:.3f}")

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    # preprocessing is inside the model, so it takes raw 0-255 pixels.
    # augmentation layers are no-ops at inference
    model.save(out)
    out.with_suffix(".labels.json").write_text(json.dumps(labels, ensure_ascii=False), encoding="utf-8")
    print("saved", out)

    if args.tflite:
        conv = tf.lite.TFLiteConverter.from_keras_model(model)
        conv.optimizations = [tf.lite.Optimize.DEFAULT]
        out.with_suffix(".tflite").write_bytes(conv.convert())
        print("saved tflite")


if __name__ == "__main__":
    main()
