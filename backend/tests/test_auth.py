def test_register_and_me(client):
    r = client.post("/api/auth/register", json={"name": "Sara", "email": "Sara@Test.sa", "password": "abc12345"})
    assert r.status_code == 201
    token = r.json()["access_token"]
    me = client.get("/api/auth/me", headers={"Authorization": f"Bearer {token}"}).json()
    assert me["email"] == "sara@test.sa"  # stored lowercase
    assert me["role"] == "parent"


def test_duplicate_email(client, parent):
    r = client.post("/api/auth/register", json={"name": "Xy", "email": "mom@test.sa", "password": "abc12345"})
    assert r.status_code == 409


def test_weak_password_rejected(client):
    r = client.post("/api/auth/register", json={"name": "Sara", "email": "a@b.sa", "password": "12345678"})
    assert r.status_code == 422


def test_cannot_register_as_admin(client):
    r = client.post(
        "/api/auth/register", json={"name": "Hacker", "email": "h@b.sa", "password": "abc12345", "role": "admin"}
    )
    assert r.status_code == 422


def test_volunteer_needs_details(client):
    r = client.post(
        "/api/auth/register",
        json={"name": "Doc", "email": "d@b.sa", "password": "abc12345", "role": "volunteer"},
    )
    assert r.status_code == 422


def test_wrong_password(client, parent):
    r = client.post("/api/auth/login", json={"email": "mom@test.sa", "password": "nope12345"})
    assert r.status_code == 401


def test_disabled_user_cannot_login(client, parent, admin):
    me = client.get("/api/auth/me", headers=parent).json()
    client.patch(f"/api/admin/users/{me['id']}", json={"is_active": False}, headers=admin)
    r = client.post("/api/auth/login", json={"email": "mom@test.sa", "password": "Pass1234"})
    assert r.status_code == 403
    # and the old token stops working too
    assert client.get("/api/auth/me", headers=parent).status_code == 401


def test_parent_cannot_open_admin(client, parent):
    assert client.get("/api/admin/stats", headers=parent).status_code == 403
