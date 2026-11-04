from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.case import CaseOut
from app.schemas.child import ChildOut


class ConsultationIn(BaseModel):
    case_id: int
    note: str | None = Field(default=None, max_length=500)


class MessageIn(BaseModel):
    body: str = Field(min_length=1, max_length=2000)


class MessageOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    consultation_id: int
    sender_id: int
    body: str
    created_at: datetime


class PersonBrief(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    specialty: str | None = None


class ConsultationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    case_id: int
    parent_id: int
    volunteer_id: int | None
    status: str
    video_link: str | None
    notes: str | None
    rating: int | None
    created_at: datetime
    start_time: datetime | None
    end_time: datetime | None
    duration_minutes: float
    volunteer: PersonBrief | None = None
    parent: PersonBrief | None = None


class ConsultationDetail(ConsultationOut):
    case: CaseOut
    child: ChildOut
    messages: list[MessageOut] = []


class EndIn(BaseModel):
    notes: str | None = Field(default=None, max_length=2000)


class RateIn(BaseModel):
    rating: int = Field(ge=1, le=5)
