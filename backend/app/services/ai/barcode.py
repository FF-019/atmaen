from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Product


def clean_barcode(raw: str) -> str:
    return "".join(ch for ch in raw if ch.isdigit())


def is_valid_ean(code: str) -> bool:
    """EAN-8 / UPC-A / EAN-13 check digit. Catches most bad camera reads."""
    if len(code) not in (8, 12, 13) or not code.isdigit():
        return False
    digits = [int(c) for c in code]
    check = digits.pop()
    # weights go 3,1,3,1... from the right, excluding the check digit
    total = sum(d * (3 if i % 2 == 0 else 1) for i, d in enumerate(reversed(digits)))
    return (10 - total % 10) % 10 == check


def lookup(db: Session, raw: str) -> Product | None:
    code = clean_barcode(raw)
    if not code:
        return None
    product = db.scalar(select(Product).where(Product.barcode == code))
    if product is None and len(code) == 12:
        # UPC-A is EAN-13 with a leading zero, some scanners give one or the other
        product = db.scalar(select(Product).where(Product.barcode == "0" + code))
    return product
