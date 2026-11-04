from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import require_admin
from app.core.database import get_db
from app.models import EducationalResource, User
from app.schemas.misc import ResourceIn, ResourceOut

router = APIRouter(prefix="/education", tags=["educational library"])


@router.get("", response_model=list[ResourceOut])
def list_resources(category: str | None = None, db: Session = Depends(get_db)):
    q = select(EducationalResource)
    if category:
        q = q.where(EducationalResource.category == category)
    return db.scalars(q.order_by(EducationalResource.category, EducationalResource.sort_order)).all()


@router.get("/{slug}", response_model=ResourceOut)
def get_resource(slug: str, db: Session = Depends(get_db)):
    r = db.scalar(select(EducationalResource).where(EducationalResource.slug == slug))
    if not r:
        raise HTTPException(404, "resource not found")
    return r


@router.post("", response_model=ResourceOut, status_code=201)
def create_resource(data: ResourceIn, admin: User = Depends(require_admin), db: Session = Depends(get_db)):
    if db.scalar(select(EducationalResource).where(EducationalResource.slug == data.slug)):
        raise HTTPException(409, "slug already used")
    r = EducationalResource(**data.model_dump())
    db.add(r)
    db.commit()
    return r


@router.put("/{slug}", response_model=ResourceOut)
def update_resource(slug: str, data: ResourceIn, admin: User = Depends(require_admin), db: Session = Depends(get_db)):
    r = db.scalar(select(EducationalResource).where(EducationalResource.slug == slug))
    if not r:
        raise HTTPException(404, "resource not found")
    for k, v in data.model_dump().items():
        setattr(r, k, v)
    db.commit()
    return r


@router.delete("/{slug}", status_code=204)
def delete_resource(slug: str, admin: User = Depends(require_admin), db: Session = Depends(get_db)):
    r = db.scalar(select(EducationalResource).where(EducationalResource.slug == slug))
    if not r:
        raise HTTPException(404, "resource not found")
    db.delete(r)
    db.commit()
