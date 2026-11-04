"""
Image recognition of the product / substance.

We trained a small MobileNetV2 (transfer learning) on photos of household
products grouped by category, see scripts/train_image_model.py. The model
outputs a category, not an exact product, the category is enough to pick a
first aid protocol.

TensorFlow is optional at runtime. If it's not installed or the model file is
missing the classifier reports itself unavailable and the app asks the parent
to scan the barcode or type the name instead.
"""

import io
import json
import logging
from pathlib import Path

from PIL import Image

from app.core.config import settings

log = logging.getLogger(__name__)

IMG_SIZE = 224
MIN_CONFIDENCE = 0.55


class ImageClassifier:
    def __init__(self, model_path: str):
        self.model_path = Path(model_path)
        self.labels_path = self.model_path.with_suffix(".labels.json")
        self._model = None
        self._labels: list[str] = []
        self._tried = False

    def _load(self):
        self._tried = True
        if not self.model_path.exists() or not self.labels_path.exists():
            log.info("image model not found at %s, image recognition disabled", self.model_path)
            return
        try:
            import tensorflow as tf  # heavy import, only when needed
        except ImportError:
            log.warning("tensorflow not installed, image recognition disabled")
            return
        self._model = tf.keras.models.load_model(self.model_path)
        self._labels = json.loads(self.labels_path.read_text(encoding="utf-8"))
        log.info("loaded image model with %d classes", len(self._labels))

    @property
    def available(self) -> bool:
        if not self._tried:
            self._load()
        return self._model is not None

    @staticmethod
    def preprocess(data: bytes):
        import numpy as np

        img = Image.open(io.BytesIO(data)).convert("RGB")
        # center crop to a square first, phone photos are 4:3 and the
        # product is usually in the middle
        w, h = img.size
        side = min(w, h)
        img = img.crop(((w - side) // 2, (h - side) // 2, (w + side) // 2, (h + side) // 2))
        img = img.resize((IMG_SIZE, IMG_SIZE))
        # raw 0-255, the saved model does the mobilenet scaling itself
        arr = np.asarray(img, dtype="float32")
        return arr[None, ...]

    def predict(self, data: bytes) -> tuple[str | None, float]:
        if not self.available:
            return None, 0.0
        probs = self._model.predict(self.preprocess(data), verbose=0)[0]
        best = int(probs.argmax())
        conf = float(probs[best])
        if conf < MIN_CONFIDENCE:
            return None, conf
        return self._labels[best], conf


classifier = ImageClassifier(settings.image_model_path)
