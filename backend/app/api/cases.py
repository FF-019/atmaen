
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.children import get_own_child
from app.api.deps import require_parent
from app.core.clock import utcnow
from app.core.config import settings
from app.core.database import get_db
from app.models import AIResult, Chemical, Child, EmergencyCase, Hospital, User
from app.schemas.case import CaseIn, CaseOut, CaseUpdate, CaseWithGuidance
from app.services.ai import barcode as bc
from app.services.ai.guidance import build_guidance
from app.services.ai.matcher import index
from app.services.geo import haversine_km, maps_link

router = APIRouter(prefix="/cases", tags=["emergency cases"])


def _own_case(db: Session, user: User, case_id: int) -> EmergencyCase:
    case = db.get(EmergencyCase, case_id)
    if not case or case.child.user_id != user.id:
        raise HTTPException(404, "case not found")
    return case


def _resolve_chemical(db: Session, data: CaseIn) -> tuple[Chemical | None, float]:
    if data.chemical_id:
        return db.get(Chemical, data.chemical_id), 1.0
    if data.input_method == "barcode" and data.input_value:
        p = bc.lookup(db, data.input_value)
        return (p.chemical, 1.0) if p else (None, 0.0)
    if data.input_method == "text" and data.input_value:
        res = index.match(db, data.input_value)
        return (db.get(Chemical, res.chemical_id) if res.chemical_id else None), res.score / 100
    return None, 0.0


@router.post("", response_model=CaseWithGuidance, status_code=201)
def open_case(data: CaseIn, user: User = Depends(require_parent), db: Session = Depends(get_db)):
    child = get_own_child(db, user, data.child_id)
    chem, conf = _resolve_chemical(db, data)

    guidance = build_guidance(chem, confidence=conf, child=child, symptoms=data.symptoms)

    case = EmergencyCase(
        child_id=child.id,
        chemical_id=chem.id if chem else None,
        input_method=data.input_method,
        input_value=data.input_value,
        symptoms=",".join(data.symptoms) or None,
        severity=guidance.severity,
        latitude=data.latitude,
        longitude=data.longitude,
    )
    db.add(case)
    db.flush()
    db.add(AIResult(
        case_id=case.id,
        method=data.input_method,
        input_text=data.input_value,
        result_text=guidance.model_dump_json(),
        confidence=guidance.confidence,
    ))
    db.commit()
    db.refresh(case)
    return CaseWithGuidance(case=CaseOut.model_validate(case), guidance=guidance)


@router.get("", response_model=list[CaseOut])
def my_cases(user: User = Depends(require_parent), db: Session = Depends(get_db)):
    q = (
        select(EmergencyCase)
        .join(Child)
        .where(Child.user_id == user.id)
        .order_by(EmergencyCase.created_at.desc())
        .limit(100)
    )
    return db.scalars(q).all()


@router.get("/{case_id}", response_model=CaseWithGuidance)
def get_case(case_id: int, user: User = Depends(require_parent), db: Session = Depends(get_db)):
    case = _own_case(db, user, case_id)
    symptoms = case.symptoms.split(",") if case.symptoms else []
    guidance = build_guidance(case.chemical, confidence=1.0 if case.chemical else 0, child=case.child, symptoms=symptoms)
    return CaseWithGuidance(case=CaseOut.model_validate(case), guidance=guidance)


@router.patch("/{case_id}", response_model=CaseWithGuidance)
def update_case(case_id: int, data: CaseUpdate, user: User = Depends(require_parent), db: Session = Depends(get_db)):
    case = _own_case(db, user, case_id)
    if data.symptoms is not None:
        case.symptoms = ",".join(data.symptoms) or None
    if data.latitude is not None and data.longitude is not None:
        case.latitude, case.longitude = data.latitude, data.longitude
    if data.status == "closed" and case.status != "closed":
        case.status = "closed"
        case.closed_at = utcnow()

    symptoms = case.symptoms.split(",") if case.symptoms else []
    guidance = build_guidance(case.chemical, confidence=1.0 if case.chemical else 0, child=case.child, symptoms=symptoms)
    case.severity = guidance.severity
    db.commit()
    db.refresh(case)
    return CaseWithGuidance(case=CaseOut.model_validate(case), guidance=guidance)


@router.get("/{case_id}/emergency")
def emergency_info(case_id: int, user: User = Depends(require_parent), db: Session = Depends(get_db)):
    """Everything the emergency screen needs in one request."""
    case = _own_case(db, user, case_id)
    child = case.child

    hospitals = []
    share = None
    if case.latitude is not None and case.longitude is not None:
        rows = db.scalars(select(Hospital).where(Hospital.has_emergency.is_(True))).all()
        ranked = sorted(rows, key=lambda h: haversine_km(case.latitude, case.longitude, h.latitude, h.longitude))
        for h in ranked[:3]:
            hospitals.append({
                "id": h.id,
                "name_ar": h.name_ar,
                "phone": h.phone,
                "distance_km": round(haversine_km(case.latitude, case.longitude, h.latitude, h.longitude), 1),
                "maps": maps_link(h.latitude, h.longitude),
            })
        substance = case.chemical.name_ar if case.chemical else (case.input_value or "مادة غير معروفة")
        share = (
            f"حالة طوارئ: الطفل {child.name} ({child.age_years} سنة"
            f"{f'، {child.weight_kg:g} كجم' if child.weight_kg else ''}) "
            f"بلع {substance}. الموقع: {maps_link(case.latitude, case.longitude)}"
        )

    return {
        "emergency_number": settings.emergency_number,
        "medical_line": settings.medical_line_number,
        "share_text": share,
        "hospitals": hospitals,
    }
