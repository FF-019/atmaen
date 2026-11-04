"""
Load the reference data (chemicals, library, hospitals) and create the first
admin. Safe to run more than once, existing rows are skipped.

    python -m scripts.seed            # reference data + admin
    python -m scripts.seed --demo     # also demo parent/volunteer and some history
"""

import argparse
import json
import random
from datetime import date, timedelta
from pathlib import Path

from sqlalchemy import select

from app import models  # noqa: F401
from app.core.clock import utcnow
from app.core.config import settings
from app.core.database import Base, SessionLocal, engine
from app.core.security import hash_password
from app.models import (
    AIResult, Chemical,
    Child,
    Consultation,
    EducationalResource,
    EmergencyCase,
    Hospital,
    Message,
    Product,
    User,
)

DATA = Path(__file__).resolve().parent.parent / "data"


def ean13(body12: str) -> str:
    digits = [int(c) for c in body12]
    total = sum(d * (3 if i % 2 else 1) for i, d in enumerate(digits))
    return body12 + str((10 - total % 10) % 10)


def seed_chemicals(db) -> int:
    added = 0
    rows = json.loads((DATA / "chemicals.json").read_text(encoding="utf-8"))
    for n, row in enumerate(rows, start=1):
        if db.scalar(select(Chemical).where(Chemical.name_en == row["name_en"])):
            continue
        brands = row.pop("brands", [])
        chem = Chemical(**row)
        db.add(chem)
        db.flush()
        for b, brand in enumerate(brands):
            # 2xx prefixes are reserved for in-store codes, so these sample
            # barcodes never clash with a real product
            code = ean13(f"20{n:04d}{b:06d}")
            db.add(Product(barcode=code, brand=brand, chemical_id=chem.id))
        added += 1
    return added


def seed_library(db) -> int:
    added = 0
    for row in json.loads((DATA / "education.json").read_text(encoding="utf-8")):
        if db.scalar(select(EducationalResource).where(EducationalResource.slug == row["slug"])):
            continue
        db.add(EducationalResource(**row))
        added += 1
    return added


def seed_hospitals(db) -> int:
    added = 0
    for row in json.loads((DATA / "hospitals.json").read_text(encoding="utf-8")):
        if db.scalar(select(Hospital).where(Hospital.name_ar == row["name_ar"])):
            continue
        db.add(Hospital(**row))
        added += 1
    return added


def seed_admin(db):
    if db.scalar(select(User).where(User.email == settings.admin_email)):
        return False
    db.add(User(
        name="مدير النظام",
        email=settings.admin_email,
        password_hash=hash_password(settings.admin_password),
        role="admin",
    ))
    return True


def seed_demo(db):
    if db.scalar(select(User).where(User.email == "parent@demo.sa")):
        print("demo data already there")
        return

    pw = hash_password("Demo@1234")
    parent = User(name="نورة الحربي", email="parent@demo.sa", phone="0550000001", password_hash=pw, role="parent")
    vol = User(
        name="د. ريم القحطاني", email="volunteer@demo.sa", phone="0550000002", password_hash=pw,
        role="volunteer", specialty="طب أطفال", institution="جامعة جازان", license_no="SCFHS-000000",
        is_verified=True, is_available=True,
    )
    vol2 = User(
        name="عبدالله مدخلي", email="student@demo.sa", password_hash=pw, role="volunteer",
        specialty="طالب امتياز", institution="كلية الطب - جامعة جازان",
    )
    db.add_all([parent, vol, vol2])
    db.flush()

    today = date.today()
    kids = [
        Child(user_id=parent.id, name="سلمان", gender="male", birth_date=today - timedelta(days=2 * 365 + 40),
              weight_kg=12.5, height_cm=88),
        Child(user_id=parent.id, name="لولوة", gender="female", birth_date=today - timedelta(days=4 * 365 + 120),
              weight_kg=16, height_cm=103, allergies="بنسلين"),
    ]
    db.add_all(kids)
    db.flush()

    # some history over the last 6 weeks so the dashboard isn't empty
    chems = db.scalars(select(Chemical)).all()
    rnd = random.Random(7)
    sev_for = {"low": "low", "moderate": "moderate", "high": "high", "critical": "critical"}
    for i in range(48):
        ch = rnd.choice(chems)
        when = utcnow() - timedelta(days=rnd.randint(0, 42), hours=rnd.randint(0, 23))
        case = EmergencyCase(
            child_id=rnd.choice(kids).id,
            chemical_id=ch.id,
            input_method=rnd.choice(["text", "text", "barcode", "image"]),
            input_value=ch.name_ar,
            severity=sev_for[ch.hazard_level],
            latitude=16.89 + rnd.random() / 50,
            longitude=42.55 + rnd.random() / 50,
            status="closed",
            created_at=when,
            closed_at=when + timedelta(minutes=rnd.randint(10, 50)),
        )
        db.add(case)
        db.flush()
        # most text lookups match, some typos don't
        conf = 1.0 if case.input_method == "barcode" else rnd.choice([1.0, 1.0, 0.95, 0.9, 0.86, 0.7])
        db.add(AIResult(case_id=case.id, method=case.input_method, input_text=case.input_value,
                        result_text="{}", confidence=conf, created_at=when))
        if rnd.random() < 0.55:
            start = when + timedelta(minutes=rnd.uniform(0.5, 4))
            c = Consultation(
                case_id=case.id, parent_id=parent.id, volunteer_id=vol.id, status="completed",
                created_at=when, start_time=start, end_time=start + timedelta(minutes=rnd.randint(6, 25)),
                rating=rnd.choice([4, 5, 5, 5]), notes="تمت الاستشارة وطمأنة الأم",
            )
            db.add(c)
            db.flush()
            db.add(Message(consultation_id=c.id, sender_id=parent.id, body="السلام عليكم، ولدي بلع شي", created_at=when))
            db.add(Message(consultation_id=c.id, sender_id=vol.id, body="وعليكم السلام، لا تخافين. كم عمره ووزنه تقريباً؟", created_at=start))
    print("demo users: parent@demo.sa / volunteer@demo.sa / student@demo.sa  (password Demo@1234)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--demo", action="store_true")
    args = ap.parse_args()

    Base.metadata.create_all(bind=engine)
    with SessionLocal() as db:
        print(f"chemicals: +{seed_chemicals(db)}")
        print(f"library:   +{seed_library(db)}")
        print(f"hospitals: +{seed_hospitals(db)}")
        if seed_admin(db):
            print(f"admin:     {settings.admin_email}")
        if args.demo:
            seed_demo(db)
        db.commit()


if __name__ == "__main__":
    main()
