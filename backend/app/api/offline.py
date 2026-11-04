"""
Offline bundle. The app downloads this once (and refreshes when the version
changes) and stores it in SQLite on the phone, so the emergency steps and the
library still work with no internet.
"""

import hashlib
import json

from fastapi import APIRouter, Depends, Response
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.models import Chemical, EducationalResource, Product
from app.services.ai import protocols as P

router = APIRouter(prefix="/offline", tags=["offline"])


def _bundle(db: Session) -> dict:
    chems = db.scalars(select(Chemical).order_by(Chemical.id)).all()
    products = db.scalars(select(Product)).all()
    resources = db.scalars(
        select(EducationalResource).where(EducationalResource.available_offline.is_(True))
    ).all()
    return {
        "emergency_number": settings.emergency_number,
        "medical_line": settings.medical_line_number,
        "universal_do_not": P.UNIVERSAL_DO_NOT,
        "red_flags": P.RED_FLAGS,
        "first_steps": [t for t, _ in P.FIRST_STEPS],
        "disclaimer": P.DISCLAIMER,
        "protocols": {
            k: {
                "headline": v["headline"],
                "severity": v["base_severity"],
                "steps": [{"text": t, "icon": i} for t, i in v["steps"]],
                "do_not": v["extra_do_not"],
                "watch_for": v["watch_for"],
            }
            for k, v in P.PROTOCOLS.items()
        },
        "chemicals": [
            {
                "id": c.id,
                "name_ar": c.name_ar,
                "name_en": c.name_en,
                "aliases": c.aliases or "",
                "category": c.category,
                "hazard_level": c.hazard_level,
            }
            for c in chems
        ],
        "products": [{"barcode": p.barcode, "chemical_id": p.chemical_id} for p in products],
        "library": [
            {
                "slug": r.slug,
                "title_ar": r.title_ar,
                "category": r.category,
                "summary_ar": r.summary_ar,
                "content_ar": r.content_ar,
            }
            for r in resources
        ],
    }


@router.get("/bundle")
def bundle(response: Response, db: Session = Depends(get_db)):
    data = _bundle(db)
    version = hashlib.sha1(json.dumps(data, sort_keys=True, ensure_ascii=False).encode()).hexdigest()[:12]
    response.headers["ETag"] = version
    return {"version": version, **data}


@router.get("/version")
def version(db: Session = Depends(get_db)):
    data = _bundle(db)
    return {"version": hashlib.sha1(json.dumps(data, sort_keys=True, ensure_ascii=False).encode()).hexdigest()[:12]}
