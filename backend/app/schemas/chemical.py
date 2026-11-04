from pydantic import BaseModel, ConfigDict, Field


class ProductOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    barcode: str
    brand: str


class ChemicalOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name_en: str
    name_ar: str
    aliases: str | None
    category: str
    hazard_level: str
    description_ar: str | None
    extra_steps_ar: str | None


class ChemicalDetail(ChemicalOut):
    products: list[ProductOut] = []


class ChemicalIn(BaseModel):
    name_en: str = Field(min_length=2, max_length=120)
    name_ar: str = Field(min_length=2, max_length=120)
    aliases: str | None = None
    category: str
    hazard_level: str = Field(default="moderate", pattern="^(low|moderate|high|critical)$")
    description_ar: str | None = None
    extra_steps_ar: str | None = None


class ChemicalUpdate(BaseModel):
    name_en: str | None = None
    name_ar: str | None = None
    aliases: str | None = None
    category: str | None = None
    hazard_level: str | None = Field(default=None, pattern="^(low|moderate|high|critical)$")
    description_ar: str | None = None
    extra_steps_ar: str | None = None


class ProductIn(BaseModel):
    barcode: str = Field(min_length=6, max_length=32)
    brand: str = Field(min_length=1, max_length=120)
