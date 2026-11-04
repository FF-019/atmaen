import pytest

from app.services.ai.barcode import is_valid_ean
from app.services.ai.normalize import normalize


@pytest.mark.parametrize(
    "text,expected",
    [
        ("كلوركس", "Bleach (sodium hypochlorite)"),
        ("بنادول", "Paracetamol (acetaminophen)"),
        ("panadol", "Paracetamol (acetaminophen)"),
        ("بطاريه ساعه", "Button battery"),
        ("الجاز", "Kerosene"),
        ("صابون مواعين", "Dish soap"),
        ("كبسولات الغسيل", "Laundry detergent pods"),
    ],
)
def test_text_matching(client, text, expected):
    g = client.post("/api/ai/analyze/text", json={"text": text}).json()
    assert g["matched"], text
    assert g["chemical"]["name_en"] == expected


def test_unknown_text_gives_safe_generic_steps(client):
    g = client.post("/api/ai/analyze/text", json={"text": "qwerty zzz"}).json()
    assert g["matched"] is False
    assert g["severity"] in ("high", "critical")
    assert len(g["steps"]) >= 3
    assert any("التقيؤ" in x for x in g["do_not"])


def test_red_flag_symptom_escalates(client):
    g = client.post("/api/ai/analyze/text", json={"text": "صابون مواعين", "symptoms": ["breathing"]}).json()
    assert g["severity"] == "critical"
    assert g["call_emergency"] is True
    assert "997" in g["steps"][0]["text"]


def test_mild_without_symptoms_stays_low(client):
    g = client.post("/api/ai/analyze/text", json={"text": "معجون أسنان"}).json()
    assert g["severity"] == "low"
    assert g["call_emergency"] is False


def test_battery_honey_step_depends_on_age(client, parent):
    baby = client.post("/api/children", json={"name": "b", "birth_date": "2026-08-01"}, headers=parent).json()
    toddler = client.post("/api/children", json={"name": "t", "birth_date": "2023-01-01"}, headers=parent).json()

    g_baby = client.post(
        "/api/ai/analyze/text", json={"text": "بطارية ساعة", "child_id": baby["id"]}, headers=parent
    ).json()
    g_tod = client.post(
        "/api/ai/analyze/text", json={"text": "بطارية ساعة", "child_id": toddler["id"]}, headers=parent
    ).json()

    assert not any("العسل" in s["text"] for s in g_baby["steps"])
    assert any("العسل" in s["text"] for s in g_tod["steps"])


def test_barcode_lookup(client):
    chem = client.get("/api/chemicals", params={"q": "Paracetamol"}).json()[0]
    detail = client.get(f"/api/chemicals/{chem['id']}").json()
    code = detail["products"][0]["barcode"]
    assert is_valid_ean(code)

    g = client.post("/api/ai/analyze/barcode", json={"barcode": code}).json()
    assert g["matched"] and g["chemical"]["id"] == chem["id"]


def test_unknown_barcode(client):
    g = client.post("/api/ai/analyze/barcode", json={"barcode": "4006381333931"}).json()
    assert g["matched"] is False
    assert g["steps"]


def test_image_without_model_falls_back(client):
    files = {"image": ("p.png", b"\x89PNG\r\n\x1a\nnotreally", "image/png")}
    r = client.post("/api/ai/analyze/image", files=files)
    assert r.status_code == 200
    assert r.json()["matched"] is False


def test_ean_check():
    assert is_valid_ean("4006381333931")
    assert not is_valid_ean("4006381333932")
    assert not is_valid_ean("123")


def test_normalize_arabic():
    assert normalize("الكُلُور") == normalize("كلور")
    assert normalize("بطارية") == normalize("بطاريه")
    assert normalize("إسيتون") == normalize("اسيتون")
