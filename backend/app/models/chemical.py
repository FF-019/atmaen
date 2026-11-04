from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class Chemical(Base):
    __tablename__ = "chemicals"

    id: Mapped[int] = mapped_column(primary_key=True)
    name_en: Mapped[str] = mapped_column(String(120), index=True)
    name_ar: Mapped[str] = mapped_column(String(120), index=True)
    # comma separated alt names / common misspellings, used by the matcher
    aliases: Mapped[str | None] = mapped_column(Text)
    category: Mapped[str] = mapped_column(String(40), index=True)
    # low / moderate / high / critical
    hazard_level: Mapped[str] = mapped_column(String(20), default="moderate")
    description_ar: Mapped[str | None] = mapped_column(Text)
    # extra steps specific to this substance, on top of the category steps
    extra_steps_ar: Mapped[str | None] = mapped_column(Text)
    updated_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now(), onupdate=func.now())

    products = relationship("Product", back_populates="chemical", cascade="all, delete-orphan")


class Product(Base):
    """A real product on the shelf. One chemical can be in many products."""

    __tablename__ = "products"

    id: Mapped[int] = mapped_column(primary_key=True)
    barcode: Mapped[str] = mapped_column(String(32), unique=True, index=True)
    brand: Mapped[str] = mapped_column(String(120))
    chemical_id: Mapped[int] = mapped_column(ForeignKey("chemicals.id", ondelete="CASCADE"))

    chemical = relationship("Chemical", back_populates="products")
