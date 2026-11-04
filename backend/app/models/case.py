from datetime import datetime

from sqlalchemy import DateTime, Float, ForeignKey, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class EmergencyCase(Base):
    __tablename__ = "emergency_cases"

    id: Mapped[int] = mapped_column(primary_key=True)
    child_id: Mapped[int] = mapped_column(ForeignKey("children.id", ondelete="CASCADE"), index=True)
    chemical_id: Mapped[int | None] = mapped_column(ForeignKey("chemicals.id", ondelete="SET NULL"))

    input_method: Mapped[str] = mapped_column(String(10))  # text | barcode | image
    input_value: Mapped[str | None] = mapped_column(String(255))
    symptoms: Mapped[str | None] = mapped_column(Text)
    severity: Mapped[str] = mapped_column(String(20), default="unknown")

    latitude: Mapped[float | None] = mapped_column(Float)
    longitude: Mapped[float | None] = mapped_column(Float)

    # open -> consulting -> closed
    status: Mapped[str] = mapped_column(String(20), default="open", index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now(), index=True)
    closed_at: Mapped[datetime | None] = mapped_column(DateTime)

    child = relationship("Child", back_populates="cases")
    chemical = relationship("Chemical")
    ai_results = relationship("AIResult", back_populates="case", cascade="all, delete-orphan")
    consultations = relationship("Consultation", back_populates="case")


class AIResult(Base):
    __tablename__ = "ai_results"

    id: Mapped[int] = mapped_column(primary_key=True)
    case_id: Mapped[int | None] = mapped_column(ForeignKey("emergency_cases.id", ondelete="CASCADE"), index=True)
    method: Mapped[str] = mapped_column(String(10))
    input_text: Mapped[str | None] = mapped_column(Text)
    result_text: Mapped[str] = mapped_column(Text)  # json of the guidance we returned
    confidence: Mapped[float] = mapped_column(Float, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    case = relationship("EmergencyCase", back_populates="ai_results")
