from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.chemical import ChemicalOut


class Step(BaseModel):
    order: int
    text: str
    icon: str | None = None
    warning: bool = False


class Guidance(BaseModel):
    """What the app shows on the first aid screen."""

    matched: bool
    confidence: float
    chemical: ChemicalOut | None = None
    candidates: list[ChemicalOut] = []
    severity: str
    call_emergency: bool
    headline: str
    do_not: list[str]
    steps: list[Step]
    watch_for: list[str]
    speech_text: str
    disclaimer: str


class AnalyzeTextIn(BaseModel):
    text: str = Field(min_length=2, max_length=200)
    child_id: int | None = None
    symptoms: list[str] = []


class AnalyzeBarcodeIn(BaseModel):
    barcode: str = Field(min_length=6, max_length=32)
    child_id: int | None = None
    symptoms: list[str] = []


class CaseIn(BaseModel):
    child_id: int
    input_method: Literal["text", "barcode", "image"]
    input_value: str | None = None
    chemical_id: int | None = None
    symptoms: list[str] = []
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)


class CaseUpdate(BaseModel):
    symptoms: list[str] | None = None
    latitude: float | None = None
    longitude: float | None = None
    status: Literal["open", "closed"] | None = None


class CaseOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    child_id: int
    chemical_id: int | None
    input_method: str
    input_value: str | None
    symptoms: str | None
    severity: str
    latitude: float | None
    longitude: float | None
    status: str
    created_at: datetime
    closed_at: datetime | None
    chemical: ChemicalOut | None = None


class CaseWithGuidance(BaseModel):
    case: CaseOut
    guidance: Guidance
