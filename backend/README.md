# Atma'en API

FastAPI backend: auth, child profiles, emergency cases, the AI module, consultations with live chat,
volunteer hours, the educational library, nearest hospitals, the offline bundle and admin reports.

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
cp .env.example .env
python -m scripts.seed --demo
uvicorn app.main:app --reload
```

Interactive docs at http://localhost:8000/docs.

## Tests

```bash
pytest -q
```

They run on a throwaway SQLite file and cover auth and roles, the text/barcode/image analysis,
age-specific steps, the full parent → volunteer consultation flow, admin reports and the offline bundle.

## Scripts

| command | what it does |
|---|---|
| `python -m scripts.seed` | chemicals, library, hospitals, first admin |
| `python -m scripts.seed --demo` | plus demo parent/volunteer and six weeks of history |
| `python -m scripts.export_offline_bundle <path>` | writes the bundle the mobile app ships with |
| `python -m scripts.train_image_model --data ./dataset` | trains the image classifier (needs `requirements-ml.txt`) |

## Layout

```
app/
  api/          one router per area (auth, children, cases, ai, consultations, ...)
  core/         settings, database, security, clock
  models/       SQLAlchemy models (from the ERD)
  schemas/      pydantic request/response models
  services/
    ai/         normalize, matcher, barcode, image_classifier, protocols, guidance
    chat.py     websocket rooms
    geo.py      distance + maps links
data/           seed json (chemicals, library, hospitals)
scripts/
tests/
```

The sample barcodes in `data/` use the 20x in-store prefix so they never collide with real products.
Hospital coordinates are approximate and should be checked before release.
