from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class Consultation(Base):
    __tablename__ = "consultations"

    id: Mapped[int] = mapped_column(primary_key=True)
    case_id: Mapped[int] = mapped_column(ForeignKey("emergency_cases.id", ondelete="CASCADE"), index=True)
    parent_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    volunteer_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), index=True)

    # pending -> active -> completed  (or cancelled)
    status: Mapped[str] = mapped_column(String(20), default="pending", index=True)
    video_link: Mapped[str | None] = mapped_column(String(255))
    notes: Mapped[str | None] = mapped_column(Text)
    rating: Mapped[int | None] = mapped_column(Integer)

    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    start_time: Mapped[datetime | None] = mapped_column(DateTime)
    end_time: Mapped[datetime | None] = mapped_column(DateTime)

    case = relationship("EmergencyCase", back_populates="consultations")
    volunteer = relationship("User", foreign_keys=[volunteer_id])
    parent = relationship("User", foreign_keys=[parent_id])
    messages = relationship(
        "Message", back_populates="consultation", order_by="Message.id", cascade="all, delete-orphan"
    )

    @property
    def duration_minutes(self) -> float:
        if not self.start_time or not self.end_time:
            return 0
        return round((self.end_time - self.start_time).total_seconds() / 60, 1)


class Message(Base):
    __tablename__ = "consultation_messages"

    id: Mapped[int] = mapped_column(primary_key=True)
    consultation_id: Mapped[int] = mapped_column(ForeignKey("consultations.id", ondelete="CASCADE"), index=True)
    sender_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    body: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    consultation = relationship("Consultation", back_populates="messages")
