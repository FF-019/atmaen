from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, selectinload

from app.api.deps import audit, require_admin
from app.core.database import get_db
from app.models import Chemical, Product, User
from app.schemas.chemical import ChemicalDetail, ChemicalIn, ChemicalOut, ChemicalUpdate, ProductIn, ProductOut
from app.services.ai import protocols
from app.services.ai.barcode import clean_barcode
from app.services.ai.matcher import index

router = APIRouter(prefix="/chemicals", tags=["chemicals"])


@router.get("/categories")
def categories():
    return [
        {"key": k, "headline": v["headline"], "base_severity": v["base_severity"]}
        for k, v in protocols.PROTOCOLS.items()
    ]


@router.get("", response_model=list[ChemicalOut])
def list_chemicals(
    q: str | None = None,
    category: str | None = None,
    limit: int = Query(50, le=500),
    offset: int = 0,
    db: Session = Depends(get_db),
):
    stmt = select(Chemical)
    if q:
        like = f"%{q.strip()}%"
        stmt = stmt.where(or_(Chemical.name_en.ilike(like), Chemical.name_ar.like(like), Chemical.aliases.like(like)))
    if category:
        stmt = stmt.where(Chemical.category == category)
    return db.scalars(stmt.order_by(Chemical.name_ar).limit(limit).offset(offset)).all()


@router.get("/count")
def count(db: Session = Depends(get_db)):
    return {
        "chemicals": db.scalar(select(func.count(Chemical.id))),
        "products": db.scalar(select(func.count(Product.id))),
    }


@router.get("/{chemical_id}", response_model=ChemicalDetail)
def get_chemical(chemical_id: int, db: Session = Depends(get_db)):
    chem = db.scalar(select(Chemical).options(selectinload(Chemical.products)).where(Chemical.id == chemical_id))
    if not chem:
        raise HTTPException(404, "chemical not found")
    return chem


# admin side ---------------------------------------------------------------

def _check_category(cat: str | None):
    if cat is not None and cat not in protocols.PROTOCOLS:
        raise HTTPException(422, f"unknown category '{cat}'")


@router.post("", response_model=ChemicalOut, status_code=201)
def create_chemical(
    data: ChemicalIn, request: Request, admin: User = Depends(require_admin), db: Session = Depends(get_db)
):
    _check_category(data.category)
    chem = Chemical(**data.model_dump())
    db.add(chem)
    db.flush()
    audit(db, request, admin, "chemical_created", f"{chem.id} {chem.name_en}")
    db.commit()
    index.dirty = True
    return chem


@router.patch("/{chemical_id}", response_model=ChemicalOut)
def update_chemical(
    chemical_id: int,
    data: ChemicalUpdate,
    request: Request,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    chem = db.get(Chemical, chemical_id)
    if not chem:
        raise HTTPException(404, "chemical not found")
    changes = data.model_dump(exclude_unset=True)
    _check_category(changes.get("category"))
    for k, v in changes.items():
        setattr(chem, k, v)
    audit(db, request, admin, "chemical_updated", f"{chem.id} {','.join(changes)}")
    db.commit()
    index.dirty = True
    return chem


@router.delete("/{chemical_id}", status_code=204)
def delete_chemical(
    chemical_id: int, request: Request, admin: User = Depends(require_admin), db: Session = Depends(get_db)
):
    chem = db.get(Chemical, chemical_id)
    if not chem:
        raise HTTPException(404, "chemical not found")
    audit(db, request, admin, "chemical_deleted", f"{chem.id} {chem.name_en}")
    db.delete(chem)
    db.commit()
    index.dirty = True


@router.post("/{chemical_id}/products", response_model=ProductOut, status_code=201)
def add_product(
    chemical_id: int, data: ProductIn, admin: User = Depends(require_admin), db: Session = Depends(get_db)
):
    if not db.get(Chemical, chemical_id):
        raise HTTPException(404, "chemical not found")
    code = clean_barcode(data.barcode)
    if db.scalar(select(Product).where(Product.barcode == code)):
        raise HTTPException(409, "barcode already linked to a product")
    p = Product(barcode=code, brand=data.brand, chemical_id=chemical_id)
    db.add(p)
    db.commit()
    return p


@router.delete("/products/{product_id}", status_code=204)
def delete_product(product_id: int, admin: User = Depends(require_admin), db: Session = Depends(get_db)):
    p = db.get(Product, product_id)
    if not p:
        raise HTTPException(404, "product not found")
    db.delete(p)
    db.commit()
