Trained models go here (ignored by git, they're too big).

- `chemical_classifier.keras` + `chemical_classifier.labels.json` — output of `scripts/train_image_model.py`
- `chemical_classifier.tflite` — optional, for running on the phone

Without these files the API still works, image recognition just reports as unavailable
and the app falls back to barcode / text input.
