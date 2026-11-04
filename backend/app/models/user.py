from datetime import datetime
from enum import Enum

from sqlalchemy import Boolean, DateTime, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class Role(str, Enum):
    parent = "parent"
    volunteer = "volunteer"
    admin = "admin"


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(120))
    email: Mapped[str] = mapped_column(String(160), unique=True, index=True)
    phone: Mapped[str | None] = mapped_column(String(20))
    password_hash: Mapped[str] = mapped_column(String(255))
    role: Mapped[str] = mapped_column(String(20), default=Role.parent.value, index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    last_login: Mapped[datetime | None] = mapped_column(DateTime)

    # volunteer only. kept on the same table, the doc's class diagram
    # treats Volunteer as a subclass of User so this is simpler than a join
    specialty: Mapped[str | None] = mapped_column(String(80))
    license_no: Mapped[str | None] = mapped_column(String(40))
    institution: Mapped[str | None] = mapped_column(String(120))
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    is_available: Mapped[bool] = mapped_column(Boolean, default=False)

    children = relationship("Child", back_populates="parent", cascade="all, delete-orphan")

    @property
    def is_volunteer(self) -> bool:
        return self.role == Role.volunteer.value
