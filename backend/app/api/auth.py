
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import audit, get_current_user
from app.core.clock import utcnow
from app.core.database import get_db
from app.core.security import create_access_token, hash_password, verify_password
from app.models import User
from app.schemas.user import LoginIn, PasswordChange, ProfileUpdate, RegisterIn, TokenOut, UserOut

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=TokenOut, status_code=201)
def register(data: RegisterIn, request: Request, db: Session = Depends(get_db)):
    email = data.email.lower()
    if db.scalar(select(User).where(User.email == email)):
        raise HTTPException(status.HTTP_409_CONFLICT, "this email is already registered")

    if data.role == "volunteer" and not (data.specialty and data.institution):
        raise HTTPException(422, "volunteers need a specialty and an institution")

    user = User(
        name=data.name.strip(),
        email=email,
        phone=data.phone,
        password_hash=hash_password(data.password),
        role=data.role,
    )
    if data.role == "volunteer":
        user.specialty = data.specialty
        user.license_no = data.license_no
        user.institution = data.institution
        # an admin has to verify volunteers before they get cases

    db.add(user)
    db.flush()
    audit(db, request, user, "register", data.role)
    db.commit()

    return TokenOut(access_token=create_access_token(user.id, user.role), user=UserOut.model_validate(user))


@router.post("/login", response_model=TokenOut)
def login(data: LoginIn, request: Request, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.email == data.email.lower()))
    if not user or not verify_password(data.password, user.password_hash):
        audit(db, request, None, "login_failed", data.email)
        db.commit()
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "wrong email or password")
    if not user.is_active:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "this account was disabled by the admin")

    user.last_login = utcnow()
    audit(db, request, user, "login")
    db.commit()
    return TokenOut(access_token=create_access_token(user.id, user.role), user=UserOut.model_validate(user))


@router.post("/logout", status_code=204)
def logout(request: Request, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    # tokens are stateless, the app just drops it. we only log the event.
    if user.is_volunteer:
        user.is_available = False
    audit(db, request, user, "logout")
    db.commit()


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(get_current_user)):
    return user


@router.patch("/me", response_model=UserOut)
def update_me(data: ProfileUpdate, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    changes = data.model_dump(exclude_unset=True)
    if not user.is_volunteer:
        changes.pop("specialty", None)
        changes.pop("institution", None)
    for k, v in changes.items():
        setattr(user, k, v)
    db.commit()
    return user


@router.post("/me/password", status_code=204)
def change_password(
    data: PasswordChange, request: Request, user: User = Depends(get_current_user), db: Session = Depends(get_db)
):
    if not verify_password(data.current_password, user.password_hash):
        raise HTTPException(400, "current password is wrong")
    user.password_hash = hash_password(data.new_password)
    audit(db, request, user, "password_changed")
    db.commit()
