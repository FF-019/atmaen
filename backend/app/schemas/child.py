from datetime import date

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ChildBase(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    gender: str | None = Field(default=None, pattern="^(male|female)$")
    birth_date: date
    weight_kg: float | None = Field(default=None, gt=0, lt=150)
    height_cm: float | None = Field(default=None, gt=20, lt=220)
    allergies: str | None = Field(default=None, max_length=255)
    conditions: str | None = None

    @field_validator("birth_date")
    @classmethod
    def not_in_future(cls, v: date) -> date:
        if v > date.today():
            raise ValueError("birth date can't be in the future")
        return v


class ChildIn(ChildBase):
    pass


class ChildUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    gender: str | None = Field(default=None, pattern="^(male|female)$")
    birth_date: date | None = None
    weight_kg: float | None = Field(default=None, gt=0, lt=150)
    height_cm: float | None = Field(default=None, gt=20, lt=220)
    allergies: str | None = None
    conditions: str | None = None


class ChildOut(ChildBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    age_years: int
    age_months: int
