import csv
import io
from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.deps import audit, require_admin
from app.core.clock import utcnow
from app.core.database import get_db
from app.models import AIResult, AuditLog, Chemical, Child, Consultation, EmergencyCase, User
from app.schemas.consultation import ConsultationOut
from app.schemas.misc import AuditOut
from app.schemas.user import UserOut

router = APIRouter(prefix="/admin", tags=["admin"], dependencies=[Depends(require_admin)])


# users -------------------------------------------------------------------

@router.get("/users", response_model=list[UserOut])
def users(
    role: str | None = None,
    q: str | None = None,
    pending: bool = False,
    limit: int = Query(100, le=500),
    offset: int = 0,
    db: Session = Depends(get_db),
):
    stmt = select(User)
    if role:
        stmt = stmt.where(User.role == role)
    if pending:
        stmt = stmt.where(User.role == "volunteer", User.is_verified.is_(False))
    if q:
        like = f"%{q}%"
        stmt = stmt.where((User.name.like(like)) | (User.email.like(like)))
    return db.scalars(stmt.order_by(User.created_at.desc()).limit(limit).offset(offset)).all()


class UserAdminUpdate(BaseModel):
    is_active: bool | None = None
    is_verified: bool | None = None


@router.patch("/users/{user_id}", response_model=UserOut)
def update_user(
    user_id: int,
    data: UserAdminUpdate,
    request: Request,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(404, "user not found")
    if user.id == admin.id and data.is_active is False:
        raise HTTPException(400, "you can't disable your own account")

    if data.is_active is not None:
        user.is_active = data.is_active
        audit(db, request, admin, "user_enabled" if data.is_active else "user_disabled", str(user.id))
    if data.is_verified is not None:
        if user.role != "volunteer":
            raise HTTPException(400, "only volunteers get verified")
        user.is_verified = data.is_verified
        if not data.is_verified:
            user.is_available = False
        audit(db, request, admin, "volunteer_verified" if data.is_verified else "volunteer_unverified", str(user.id))
    db.commit()
    return user


# monitoring --------------------------------------------------------------

@router.get("/consultations", response_model=list[ConsultationOut])
def consultations(status: str | None = None, limit: int = Query(100, le=500), db: Session = Depends(get_db)):
    stmt = select(Consultation)
    if status:
        stmt = stmt.where(Consultation.status == status)
    return db.scalars(stmt.order_by(Consultation.created_at.desc()).limit(limit)).all()


@router.get("/audit", response_model=list[AuditOut])
def audit_log(action: str | None = None, limit: int = Query(200, le=1000), db: Session = Depends(get_db)):
    stmt = select(AuditLog)
    if action:
        stmt = stmt.where(AuditLog.action == action)
    return db.scalars(stmt.order_by(AuditLog.id.desc()).limit(limit)).all()


# reports -----------------------------------------------------------------

def _count(db: Session, stmt) -> int:
    return db.scalar(select(func.count()).select_from(stmt.subquery())) or 0


@router.get("/stats")
def stats(days: int = Query(30, ge=1, le=365), db: Session = Depends(get_db)):
    since = utcnow() - timedelta(days=days)

    cases = db.scalars(select(EmergencyCase).where(EmergencyCase.created_at >= since)).all()
    consults = db.scalars(select(Consultation).where(Consultation.created_at >= since)).all()

    by_day: dict[str, int] = {}
    by_severity: dict[str, int] = {}
    by_method: dict[str, int] = {}
    by_substance: dict[str, int] = {}
    for c in cases:
        d = c.created_at.strftime("%Y-%m-%d")
        by_day[d] = by_day.get(d, 0) + 1
        by_severity[c.severity] = by_severity.get(c.severity, 0) + 1
        by_method[c.input_method] = by_method.get(c.input_method, 0) + 1
        name = c.chemical.name_ar if c.chemical else "غير معروف"
        by_substance[name] = by_substance.get(name, 0) + 1

    # minutes from request to a volunteer accepting it
    waits = [
        (c.start_time - c.created_at).total_seconds() / 60
        for c in consults
        if c.start_time and c.created_at
    ]
    completed = [c for c in consults if c.status == "completed"]
    ratings = [c.rating for c in completed if c.rating]

    ai_rows = db.scalars(select(AIResult.confidence).where(AIResult.created_at >= since)).all()
    matched = [x for x in ai_rows if x >= 0.82]

    return {
        "period_days": days,
        "totals": {
            "parents": _count(db, select(User).where(User.role == "parent")),
            "volunteers": _count(db, select(User).where(User.role == "volunteer", User.is_verified.is_(True))),
            "pending_volunteers": _count(db, select(User).where(User.role == "volunteer", User.is_verified.is_(False))),
            "children": _count(db, select(Child)),
            "chemicals": _count(db, select(Chemical)),
        },
        "cases": len(cases),
        "critical_cases": by_severity.get("critical", 0),
        "consultations": len(consults),
        "completed_consultations": len(completed),
        "avg_wait_minutes": round(sum(waits) / len(waits), 1) if waits else None,
        "avg_rating": round(sum(ratings) / len(ratings), 2) if ratings else None,
        "ai_requests": len(ai_rows),
        "ai_match_rate": round(len(matched) / len(ai_rows), 3) if ai_rows else None,
        "cases_by_day": [{"date": k, "count": v} for k, v in sorted(by_day.items())],
        "by_severity": by_severity,
        "by_method": by_method,
        "top_substances": sorted(
            [{"name": k, "count": v} for k, v in by_substance.items()], key=lambda x: -x["count"]
        )[:8],
        "volunteers_online": _count(db, select(User).where(User.role == "volunteer", User.is_available.is_(True))),
    }


@router.get("/reports/cases.csv")
def cases_csv(days: int = Query(30, ge=1, le=365), db: Session = Depends(get_db)):
    since = utcnow() - timedelta(days=days)
    rows = db.scalars(
        select(EmergencyCase).where(EmergencyCase.created_at >= since).order_by(EmergencyCase.created_at)
    ).all()

    buf = io.StringIO()
    buf.write("﻿")  # BOM so excel opens arabic correctly
    w = csv.writer(buf)
    # no names or locations in the export, ids and aggregates only
    w.writerow(["case_id", "date", "child_age_months", "substance", "category", "method", "severity", "status"])
    for c in rows:
        w.writerow([
            c.id,
            c.created_at.isoformat(timespec="minutes"),
            c.child.age_months,
            c.chemical.name_en if c.chemical else "",
            c.chemical.category if c.chemical else "unknown",
            c.input_method,
            c.severity,
            c.status,
        ])
    buf.seek(0)
    return StreamingResponse(
        iter([buf.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": f'attachment; filename="atmaen-cases-{days}d.csv"'},
    )
