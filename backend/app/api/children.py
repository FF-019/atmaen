from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import require_parent
from app.core.database import get_db
from app.models import Child, EmergencyCase, User
from app.schemas.case import CaseOut
from app.schemas.child import ChildIn, ChildOut, ChildUpdate

router = APIRouter(prefix="/children", tags=["children"])

MAX_CHILDREN = 12


def get_own_child(db: Session, user: User, child_id: int) -> Child:
    child = db.get(Child, child_id)
    if not child or child.user_id != user.id:
        raise HTTPException(404, "child not found")
    return child


@router.get("", response_model=list[ChildOut])
def list_children(user: User = Depends(require_parent), db: Session = Depends(get_db)):
    return db.scalars(select(Child).where(Child.user_id == user.id).order_by(Child.birth_date.desc())).all()


@router.post("", response_model=ChildOut, status_code=201)
def add_child(data: ChildIn, user: User = Depends(require_parent), db: Session = Depends(get_db)):
    count = len(db.scalars(select(Child.id).where(Child.user_id == user.id)).all())
    if count >= MAX_CHILDREN:
        raise HTTPException(400, "too many children on one account")
    child = Child(user_id=user.id, **data.model_dump())
    db.add(child)
    db.commit()
    db.refresh(child)
    return child


@router.get("/{child_id}", response_model=ChildOut)
def get_child(child_id: int, user: User = Depends(require_parent), db: Session = Depends(get_db)):
    return get_own_child(db, user, child_id)


@router.patch("/{child_id}", response_model=ChildOut)
def update_child(
    child_id: int, data: ChildUpdate, user: User = Depends(require_parent), db: Session = Depends(get_db)
):
    child = get_own_child(db, user, child_id)
    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(child, k, v)
    db.commit()
    return child


@router.delete("/{child_id}", status_code=204)
def delete_child(child_id: int, user: User = Depends(require_parent), db: Session = Depends(get_db)):
    db.delete(get_own_child(db, user, child_id))
    db.commit()


@router.get("/{child_id}/cases", response_model=list[CaseOut])
def child_history(child_id: int, user: User = Depends(require_parent), db: Session = Depends(get_db)):
    get_own_child(db, user, child_id)
    q = select(EmergencyCase).where(EmergencyCase.child_id == child_id).order_by(EmergencyCase.created_at.desc())
    return db.scalars(q).all()
