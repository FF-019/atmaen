"""The main scenario from the sequence diagrams: parent -> case -> volunteer -> done."""


def test_children_are_private(client, parent, child):
    r = client.post("/api/auth/register", json={"name": "Xy", "email": "other@t.sa", "password": "abc12345"})
    other = {"Authorization": f"Bearer {r.json()['access_token']}"}
    assert client.get(f"/api/children/{child['id']}", headers=other).status_code == 404
    assert client.get("/api/children", headers=other).json() == []


def test_child_age(client, child):
    assert child["age_years"] >= 3
    assert child["age_months"] >= 36


def test_future_birth_date(client, parent):
    r = client.post("/api/children", json={"name": "x", "birth_date": "2999-01-01"}, headers=parent)
    assert r.status_code == 422


def test_full_consultation(client, parent, volunteer, child):
    # parent opens a case
    r = client.post(
        "/api/cases",
        json={
            "child_id": child["id"],
            "input_method": "text",
            "input_value": "كلوركس",
            "symptoms": ["vomiting"],
            "latitude": 16.89,
            "longitude": 42.56,
        },
        headers=parent,
    )
    assert r.status_code == 201
    case = r.json()["case"]
    assert case["chemical"]["name_en"].startswith("Bleach")

    em = client.get(f"/api/cases/{case['id']}/emergency", headers=parent).json()
    assert em["emergency_number"] == "997"
    assert em["hospitals"][0]["distance_km"] < 5
    assert "maps.google.com" in em["share_text"]

    # asks for a volunteer, pressing twice gives the same consultation
    c1 = client.post("/api/consultations", json={"case_id": case["id"]}, headers=parent).json()
    c2 = client.post("/api/consultations", json={"case_id": case["id"]}, headers=parent).json()
    assert c1["id"] == c2["id"]

    q = client.get("/api/consultations/queue", headers=volunteer).json()
    assert [x["id"] for x in q] == [c1["id"]]

    acc = client.post(f"/api/consultations/{c1['id']}/accept", headers=volunteer).json()
    assert acc["status"] == "active"
    assert acc["video_link"].startswith("https://meet.jit.si/")

    hist = client.get(f"/api/consultations/{c1['id']}/child-history", headers=volunteer).json()
    assert hist["child"]["weight_kg"] == 12.5

    client.post(f"/api/consultations/{c1['id']}/messages", json={"body": "بلع تقريباً ملعقة"}, headers=parent)
    client.post(f"/api/consultations/{c1['id']}/messages", json={"body": "اعطيه ماء"}, headers=volunteer)
    d = client.get(f"/api/consultations/{c1['id']}", headers=parent).json()
    assert len(d["messages"]) == 2

    done = client.post(f"/api/consultations/{c1['id']}/end", json={"notes": "ok"}, headers=volunteer).json()
    assert done["status"] == "completed"

    assert client.post(f"/api/consultations/{c1['id']}/rate", json={"rating": 5}, headers=parent).status_code == 200

    hours = client.get("/api/volunteers/me/hours", headers=volunteer).json()
    assert hours["consultations"] == 1
    assert hours["avg_rating"] == 5

    # case is closed after the consultation
    assert client.get(f"/api/cases/{case['id']}", headers=parent).json()["case"]["status"] == "closed"


def test_second_volunteer_cannot_take_taken_case(client, parent, volunteer, child, admin):
    case = client.post(
        "/api/cases", json={"child_id": child["id"], "input_method": "text", "input_value": "جاز"}, headers=parent
    ).json()["case"]
    c = client.post("/api/consultations", json={"case_id": case["id"]}, headers=parent).json()

    r = client.post(
        "/api/auth/register",
        json={"name": "D2", "email": "d2@t.sa", "password": "abc12345", "role": "volunteer",
              "specialty": "ER", "institution": "KFCH"},
    )
    v2 = {"Authorization": f"Bearer {r.json()['access_token']}"}
    client.patch(f"/api/admin/users/{r.json()['user']['id']}", json={"is_verified": True}, headers=admin)

    assert client.post(f"/api/consultations/{c['id']}/accept", headers=volunteer).status_code == 200
    assert client.post(f"/api/consultations/{c['id']}/accept", headers=v2).status_code == 409


def test_unverified_volunteer_has_no_queue(client):
    r = client.post(
        "/api/auth/register",
        json={"name": "Dr", "email": "new@t.sa", "password": "abc12345", "role": "volunteer",
              "specialty": "x", "institution": "y"},
    )
    h = {"Authorization": f"Bearer {r.json()['access_token']}"}
    assert client.get("/api/consultations/queue", headers=h).status_code == 403


def test_admin_stats_and_csv(client, admin, parent, child):
    client.post(
        "/api/cases", json={"child_id": child["id"], "input_method": "text", "input_value": "بنادول"}, headers=parent
    )
    s = client.get("/api/admin/stats", headers=admin).json()
    assert s["cases"] == 1
    assert s["totals"]["chemicals"] > 30

    csv = client.get("/api/admin/reports/cases.csv", headers=admin)
    assert csv.status_code == 200
    assert "Paracetamol" in csv.text
    assert "Salman" not in csv.text  # no names in exports


def test_admin_chemical_crud_updates_matcher(client, admin):
    r = client.post(
        "/api/chemicals",
        json={"name_en": "Henna dye", "name_ar": "صبغة حناء سوداء", "category": "corrosive", "hazard_level": "high"},
        headers=admin,
    )
    assert r.status_code == 201
    g = client.post("/api/ai/analyze/text", json={"text": "حناء سوداء"}).json()
    assert g["matched"] and g["chemical"]["name_en"] == "Henna dye"

    bad = client.post(
        "/api/chemicals", json={"name_en": "X", "name_ar": "اكس", "category": "nope"}, headers=admin
    )
    assert bad.status_code == 422


def test_offline_bundle(client):
    b = client.get("/api/offline/bundle").json()
    assert b["version"]
    assert "button_battery" in b["protocols"]
    assert len(b["chemicals"]) > 30
    assert len(b["library"]) >= 10


def test_nearest_hospital(client):
    rows = client.get("/api/hospitals/nearest", params={"lat": 24.69, "lng": 46.70}).json()
    assert rows[0]["city"] == "الرياض"
    assert rows == sorted(rows, key=lambda h: h["distance_km"])
