from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ResourceOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    slug: str
    title_ar: str
    title_en: str | None
    category: str
    summary_ar: str | None
    content_ar: str
    media_type: str
    media_path: str | None
    available_offline: bool
    sort_order: int
    updated_at: datetime | None = None


class ResourceIn(BaseModel):
    slug: str = Field(pattern=r"^[a-z0-9-]{3,80}$")
    title_ar: str
    title_en: str | None = None
    category: str
    summary_ar: str | None = None
    content_ar: str
    media_type: str = Field(default="text", pattern="^(text|image|video)$")
    media_path: str | None = None
    available_offline: bool = True
    sort_order: int = 0


class HospitalOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name_ar: str
    name_en: str | None
    city: str
    latitude: float
    longitude: float
    phone: str | None
    has_emergency: bool
    distance_km: float | None = None


class AuditOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int | None
    action: str
    detail: str | None
    ip: str | None
    created_at: datetime
