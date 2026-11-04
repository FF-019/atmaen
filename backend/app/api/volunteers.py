from datetime import timedelta

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import require_volunteer
from app.core.clock import utcnow
from app.core.database import get_db
from app.models import Consultation, User

router = APIRouter(prefix="/volunteers", tags=["volunteers"])


class AvailabilityIn(BaseModel):
    available: bool


@router.post("/me/availability")
def set_availability(data: AvailabilityIn, user: User = Depends(require_volunteer), db: Session = Depends(get_db)):
    user.is_available = data.available and user.is_verified
    db.commit()
    return {"available": user.is_available, "verified": user.is_verified}


@router.get("/me/hours")
def service_hours(user: User = Depends(require_volunteer), db: Session = Depends(get_db)):
    """Volunteer hours log. The certificate letter uses the total."""
    rows = db.scalars(
        select(Consultation)
        .where(Consultation.volunteer_id == user.id, Consultation.status == "completed")
        .order_by(Consultation.end_time.desc())
    ).all()

    total_min = sum(c.duration_minutes for c in rows)
    month_ago = utcnow() - timedelta(days=30)
    month_min = sum(c.duration_minutes for c in rows if c.end_time and c.end_time >= month_ago)
    rated = [c.rating for c in rows if c.rating]

    by_month: dict[str, float] = {}
    for c in rows:
        if c.end_time:
            key = c.end_time.strftime("%Y-%m")
            by_month[key] = by_month.get(key, 0) + c.duration_minutes

    return {
        "consultations": len(rows),
        "total_hours": round(total_min / 60, 2),
        "last_30_days_hours": round(month_min / 60, 2),
        "avg_rating": round(sum(rated) / len(rated), 2) if rated else None,
        "by_month": [{"month": k, "hours": round(v / 60, 2)} for k, v in sorted(by_month.items())],
        "log": [
            {
                "id": c.id,
                "date": c.end_time,
                "minutes": c.duration_minutes,
                "severity": c.case.severity,
                "rating": c.rating,
            }
            for c in rows[:50]
        ],
    }
