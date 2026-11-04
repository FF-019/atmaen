from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models import Hospital
from app.schemas.misc import HospitalOut
from app.services.geo import haversine_km

router = APIRouter(prefix="/hospitals", tags=["hospitals"])


@router.get("/nearest", response_model=list[HospitalOut])
def nearest(
    lat: float = Query(ge=-90, le=90),
    lng: float = Query(ge=-180, le=180),
    limit: int = Query(5, ge=1, le=20),
    db: Session = Depends(get_db),
):
    rows = db.scalars(select(Hospital).where(Hospital.has_emergency.is_(True))).all()
    out = []
    for h in rows:
        item = HospitalOut.model_validate(h)
        item.distance_km = round(haversine_km(lat, lng, h.latitude, h.longitude), 1)
        out.append(item)
    out.sort(key=lambda h: h.distance_km)
    return out[:limit]
