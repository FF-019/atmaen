import os
import sys
from pathlib import Path

import pytest

# use a throwaway sqlite file per test run, set before the app imports settings
DB_FILE = Path(__file__).parent / "_test.db"
os.environ["DATABASE_URL"] = f"sqlite:///{DB_FILE}"
os.environ["ADMIN_EMAIL"] = "admin@test.sa"
os.environ["ADMIN_PASSWORD"] = "Admin@12345"
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from fastapi.testclient import TestClient  # noqa: E402

from app.core.database import Base, SessionLocal, engine  # noqa: E402
from app.main import app  # noqa: E402
from app.services.ai.matcher import index  # noqa: E402
from scripts import seed  # noqa: E402


@pytest.fixture(autouse=True)
def fresh_db():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    with SessionLocal() as db:
        seed.seed_chemicals(db)
        seed.seed_library(db)
        seed.seed_hospitals(db)
        seed.seed_admin(db)
        db.commit()
    index.dirty = True
    yield


@pytest.fixture(scope="session", autouse=True)
def cleanup():
    yield
    engine.dispose()
    DB_FILE.unlink(missing_ok=True)


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c


def _register(client, email, role="parent", **extra):
    body = {"name": "Test User", "email": email, "password": "Pass1234", "role": role, **extra}
    r = client.post("/api/auth/register", json=body)
    assert r.status_code == 201, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}, r.json()["user"]


@pytest.fixture
def parent(client):
    headers, _ = _register(client, "mom@test.sa")
    return headers


@pytest.fixture
def admin(client):
    r = client.post("/api/auth/login", json={"email": "admin@test.sa", "password": "Admin@12345"})
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def volunteer(client, admin):
    headers, user = _register(
        client, "doc@test.sa", role="volunteer", specialty="Pediatrics", institution="Jazan University"
    )
    client.patch(f"/api/admin/users/{user['id']}", json={"is_verified": True}, headers=admin)
    return headers


@pytest.fixture
def child(client, parent):
    r = client.post(
        "/api/children",
        json={"name": "Salman", "birth_date": "2023-01-10", "weight_kg": 12.5, "gender": "male"},
        headers=parent,
    )
    return r.json()
