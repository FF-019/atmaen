import json

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy.orm import Session

from app.api.deps import get_optional_user
from app.core.database import get_db
from app.models import AIResult, Chemical, Child, User
from app.schemas.case import AnalyzeBarcodeIn, AnalyzeTextIn, Guidance
from app.services.ai import barcode as bc
from app.services.ai.guidance import build_guidance
from app.services.ai.image_classifier import classifier
from app.services.ai.matcher import index

router = APIRouter(prefix="/ai", tags=["ai"])

MAX_IMAGE_BYTES = 6 * 1024 * 1024


def _child_for(db: Session, user: User | None, child_id: int | None) -> Child | None:
    if not user or not child_id:
        return None
    child = db.get(Child, child_id)
    return child if child and child.user_id == user.id else None


def _log(db: Session, method: str, input_text: str, g: Guidance):
    # case_id stays empty here, it gets linked when the parent opens a case
    db.add(AIResult(method=method, input_text=input_text, result_text=g.model_dump_json(), confidence=g.confidence))
    db.commit()


@router.post("/analyze/text", response_model=Guidance)
def analyze_text(
    data: AnalyzeTextIn, user: User | None = Depends(get_optional_user), db: Session = Depends(get_db)
):
    res = index.match(db, data.text)
    chem = db.get(Chemical, res.chemical_id) if res.chemical_id else None
    candidates = [db.get(Chemical, cid) for cid, _ in res.candidates if cid != res.chemical_id]
    g = build_guidance(
        chem,
        confidence=res.score / 100,
        child=_child_for(db, user, data.child_id),
        symptoms=data.symptoms,
        candidates=[c for c in candidates if c],
    )
    _log(db, "text", data.text, g)
    return g


@router.post("/analyze/barcode", response_model=Guidance)
def analyze_barcode(
    data: AnalyzeBarcodeIn, user: User | None = Depends(get_optional_user), db: Session = Depends(get_db)
):
    code = bc.clean_barcode(data.barcode)
    product = bc.lookup(db, code)
    if product is None:
        # still give the safe generic steps, never return an empty screen
        g = build_guidance(None, child=_child_for(db, user, data.child_id), symptoms=data.symptoms)
    else:
        g = build_guidance(
            product.chemical, confidence=1.0, child=_child_for(db, user, data.child_id), symptoms=data.symptoms
        )
    _log(db, "barcode", code, g)
    return g


@router.post("/analyze/image", response_model=Guidance)
async def analyze_image(
    image: UploadFile = File(...),
    child_id: int | None = Form(None),
    symptoms: str = Form("[]"),
    user: User | None = Depends(get_optional_user),
    db: Session = Depends(get_db),
):
    if image.content_type not in ("image/jpeg", "image/png", "image/webp"):
        raise HTTPException(415, "send a jpeg, png or webp image")
    data = await image.read()
    if len(data) > MAX_IMAGE_BYTES:
        raise HTTPException(413, "image too large")

    try:
        symptom_list = json.loads(symptoms)
    except json.JSONDecodeError:
        symptom_list = []

    category, conf = classifier.predict(data)
    g = build_guidance(
        None,
        category=category,
        confidence=conf,
        child=_child_for(db, user, child_id),
        symptoms=symptom_list,
    )
    _log(db, "image", image.filename or "", g)
    return g


@router.get("/status")
def status():
    return {"text": True, "barcode": True, "image": classifier.available}
