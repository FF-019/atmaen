from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class EducationalResource(Base):
    __tablename__ = "educational_resources"

    id: Mapped[int] = mapped_column(primary_key=True)
    slug: Mapped[str] = mapped_column(String(80), unique=True)
    title_ar: Mapped[str] = mapped_column(String(160))
    title_en: Mapped[str | None] = mapped_column(String(160))
    # ingestion / choking / burns / bleeding / prevention
    category: Mapped[str] = mapped_column(String(40), index=True)
    summary_ar: Mapped[str | None] = mapped_column(String(255))
    content_ar: Mapped[str] = mapped_column(Text)  # markdown-ish, one step per line
    media_type: Mapped[str] = mapped_column(String(10), default="text")  # text | image | video
    media_path: Mapped[str | None] = mapped_column(String(255))
    available_offline: Mapped[bool] = mapped_column(Boolean, default=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    updated_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now(), onupdate=func.now())


class Hospital(Base):
    __tablename__ = "hospitals"

    id: Mapped[int] = mapped_column(primary_key=True)
    name_ar: Mapped[str] = mapped_column(String(160))
    name_en: Mapped[str | None] = mapped_column(String(160))
    city: Mapped[str] = mapped_column(String(60), index=True)
    latitude: Mapped[float] = mapped_column(Float)
    longitude: Mapped[float] = mapped_column(Float)
    phone: Mapped[str | None] = mapped_column(String(20))
    has_emergency: Mapped[bool] = mapped_column(Boolean, default=True)


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    action: Mapped[str] = mapped_column(String(60), index=True)
    detail: Mapped[str | None] = mapped_column(Text)
    ip: Mapped[str | None] = mapped_column(String(45))
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now(), index=True)
