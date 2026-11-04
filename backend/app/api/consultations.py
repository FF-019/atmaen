import secrets

import jwt
from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_parent, require_volunteer
from app.core.clock import utcnow
from app.core.database import SessionLocal, get_db
from app.core.security import decode_token
from app.models import Child, Consultation, EmergencyCase, Message, User
from app.schemas.consultation import (
    ConsultationDetail,
    ConsultationIn,
    ConsultationOut,
    EndIn,
    MessageIn,
    MessageOut,
    RateIn,
)
from app.services.chat import hub

router = APIRouter(prefix="/consultations", tags=["consultations"])

SEVERITY_RANK = {"critical": 0, "high": 1, "moderate": 2, "low": 3, "unknown": 2}


def _can_see(c: Consultation, user: User) -> bool:
    if user.role == "admin":
        return True
    if user.id == c.parent_id:
        return True
    if user.role == "volunteer":
        # any verified volunteer can preview a pending request before accepting it
        return c.volunteer_id == user.id or (c.status == "pending" and user.is_verified)
    return False


def _get(db: Session, cid: int, user: User) -> Consultation:
    c = db.get(Consultation, cid)
    if not c or not _can_see(c, user):
        raise HTTPException(404, "consultation not found")
    return c


def _detail(c: Consultation) -> ConsultationDetail:
    return ConsultationDetail.model_validate({
        **ConsultationOut.model_validate(c).model_dump(),
        "case": c.case,
        "child": c.case.child,
        "messages": c.messages,
    })


# parent ------------------------------------------------------------------

@router.post("", response_model=ConsultationOut, status_code=201)
def request_consultation(data: ConsultationIn, user: User = Depends(require_parent), db: Session = Depends(get_db)):
    case = db.get(EmergencyCase, data.case_id)
    if not case or case.child.user_id != user.id:
        raise HTTPException(404, "case not found")

    open_one = db.scalar(
        select(Consultation).where(
            Consultation.case_id == case.id, Consultation.status.in_(("pending", "active"))
        )
    )
    if open_one:
        return open_one  # double tap on the button, just return the existing one

    c = Consultation(case_id=case.id, parent_id=user.id, notes=data.note)
    case.status = "consulting"
    db.add(c)
    db.commit()
    db.refresh(c)
    return c


@router.get("/mine", response_model=list[ConsultationOut])
def my_consultations(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if user.role == "volunteer":
        q = select(Consultation).where(Consultation.volunteer_id == user.id)
    else:
        q = select(Consultation).where(Consultation.parent_id == user.id)
    return db.scalars(q.order_by(Consultation.created_at.desc()).limit(100)).all()


@router.post("/{cid}/cancel", response_model=ConsultationOut)
async def cancel(cid: int, user: User = Depends(require_parent), db: Session = Depends(get_db)):
    c = _get(db, cid, user)
    if c.status not in ("pending", "active"):
        raise HTTPException(400, "consultation already finished")
    c.status = "cancelled"
    c.end_time = utcnow()
    c.case.status = "open"
    db.commit()
    await hub.broadcast(c.id, {"type": "status", "status": c.status})
    return c


@router.post("/{cid}/rate", response_model=ConsultationOut)
def rate(cid: int, data: RateIn, user: User = Depends(require_parent), db: Session = Depends(get_db)):
    c = _get(db, cid, user)
    if c.status != "completed":
        raise HTTPException(400, "you can rate after the consultation ends")
    c.rating = data.rating
    db.commit()
    return c


# volunteer ---------------------------------------------------------------

@router.get("/queue", response_model=list[ConsultationDetail])
def queue(user: User = Depends(require_volunteer), db: Session = Depends(get_db)):
    if not user.is_verified:
        raise HTTPException(403, "your account is waiting for admin verification")
    rows = db.scalars(select(Consultation).where(Consultation.status == "pending")).all()
    # most dangerous first, then oldest
    rows.sort(key=lambda c: (SEVERITY_RANK.get(c.case.severity, 2), c.created_at))
    return [_detail(c) for c in rows]


@router.post("/{cid}/accept", response_model=ConsultationDetail)
async def accept(cid: int, user: User = Depends(require_volunteer), db: Session = Depends(get_db)):
    if not user.is_verified:
        raise HTTPException(403, "your account is waiting for admin verification")
    c = db.get(Consultation, cid)
    if not c:
        raise HTTPException(404, "consultation not found")
    if c.status != "pending":
        raise HTTPException(409, "another volunteer already took this case")

    c.volunteer_id = user.id
    c.status = "active"
    c.start_time = utcnow()
    c.video_link = f"https://meet.jit.si/atmaen-{c.id}-{secrets.token_urlsafe(8)}"
    db.commit()
    db.refresh(c)
    await hub.broadcast(c.id, {"type": "status", "status": "active", "volunteer": user.name, "video_link": c.video_link})
    return _detail(c)


@router.post("/{cid}/end", response_model=ConsultationOut)
async def end(cid: int, data: EndIn, user: User = Depends(require_volunteer), db: Session = Depends(get_db)):
    c = _get(db, cid, user)
    if c.volunteer_id != user.id or c.status != "active":
        raise HTTPException(400, "you can only end your own active consultation")
    c.status = "completed"
    c.end_time = utcnow()
    if data.notes:
        c.notes = data.notes
    c.case.status = "closed"
    c.case.closed_at = c.end_time
    db.commit()
    await hub.broadcast(c.id, {"type": "status", "status": "completed"})
    return c


# both --------------------------------------------------------------------

@router.get("/{cid}", response_model=ConsultationDetail)
def detail(cid: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return _detail(_get(db, cid, user))


@router.get("/{cid}/child-history")
def child_history(cid: int, user: User = Depends(require_volunteer), db: Session = Depends(get_db)):
    c = _get(db, cid, user)
    child: Child = c.case.child
    past = db.scalars(
        select(EmergencyCase)
        .where(EmergencyCase.child_id == child.id, EmergencyCase.id != c.case_id)
        .order_by(EmergencyCase.created_at.desc())
        .limit(20)
    ).all()
    return {
        "child": {
            "name": child.name,
            "age_years": child.age_years,
            "age_months": child.age_months,
            "weight_kg": child.weight_kg,
            "height_cm": child.height_cm,
            "allergies": child.allergies,
            "conditions": child.conditions,
        },
        "previous_cases": [
            {
                "id": p.id,
                "date": p.created_at,
                "substance": p.chemical.name_ar if p.chemical else p.input_value,
                "severity": p.severity,
            }
            for p in past
        ],
    }


@router.post("/{cid}/messages", response_model=MessageOut, status_code=201)
async def send_message(cid: int, data: MessageIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    c = _get(db, cid, user)
    if user.id not in (c.parent_id, c.volunteer_id):
        raise HTTPException(403, "only the parent and the volunteer can write here")
    if c.status not in ("pending", "active"):
        raise HTTPException(400, "this consultation is closed")
    m = Message(consultation_id=c.id, sender_id=user.id, body=data.body.strip())
    db.add(m)
    db.commit()
    db.refresh(m)
    out = MessageOut.model_validate(m)
    await hub.broadcast(c.id, {"type": "message", "message": out.model_dump(mode="json")})
    return out


@router.websocket("/{cid}/ws")
async def chat_socket(ws: WebSocket, cid: int, token: str = Query(...)):
    # websockets can't send an Authorization header from the browser,
    # so the token comes in the query string
    db = SessionLocal()
    try:
        try:
            user = db.get(User, int(decode_token(token)["sub"]))
        except (jwt.PyJWTError, KeyError, ValueError):
            user = None
        c = db.get(Consultation, cid)
        if not user or not c or user.id not in (c.parent_id, c.volunteer_id) and user.role != "admin":
            await ws.close(code=4403)
            return
        user_id = user.id
    finally:
        db.close()

    await hub.join(cid, ws)
    await hub.broadcast(cid, {"type": "presence", "online": hub.online(cid)})
    try:
        while True:
            msg = await ws.receive_json()
            # clients only send typing events over the socket, messages go
            # through POST so they're saved even if the socket drops
            if msg.get("type") == "typing":
                await hub.broadcast(cid, {"type": "typing", "user_id": user_id})
    except WebSocketDisconnect:
        pass
    finally:
        await hub.leave(cid, ws)
        await hub.broadcast(cid, {"type": "presence", "online": hub.online(cid)})
