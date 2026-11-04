import jwt
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import decode_token
from app.models import AuditLog, User

bearer = HTTPBearer(auto_error=False)


def _user_from_token(token: str, db: Session) -> User:
    try:
        payload = decode_token(token)
    except jwt.ExpiredSignatureError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "session expired, please log in again")
    except jwt.PyJWTError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "invalid token")

    user = db.get(User, int(payload["sub"]))
    if not user or not user.is_active:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "account not found or disabled")
    return user


def get_current_user(
    creds: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: Session = Depends(get_db),
) -> User:
    if creds is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "not authenticated")
    return _user_from_token(creds.credentials, db)


def get_optional_user(
    creds: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: Session = Depends(get_db),
) -> User | None:
    # the analyze endpoints must work for someone who isn't logged in yet.
    # a panicking parent shouldn't have to sign up first.
    if creds is None:
        return None
    try:
        return _user_from_token(creds.credentials, db)
    except HTTPException:
        return None


def require_role(*roles: str):
    def checker(user: User = Depends(get_current_user)) -> User:
        if user.role not in roles:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "you don't have access to this")
        return user

    return checker


require_parent = require_role("parent")
require_volunteer = require_role("volunteer")
require_admin = require_role("admin")


def audit(db: Session, request: Request | None, user: User | None, action: str, detail: str = ""):
    ip = request.client.host if request and request.client else None
    db.add(AuditLog(user_id=user.id if user else None, action=action, detail=detail[:1000], ip=ip))
