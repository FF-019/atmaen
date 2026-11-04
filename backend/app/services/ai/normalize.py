import re
import unicodedata

_DIACRITICS = re.compile(r"[ؐ-ًؚ-ٰٟۖ-ۭ]")
_TATWEEL = "ـ"

_ARABIC_MAP = str.maketrans({
    "أ": "ا", "إ": "ا", "آ": "ا", "ٱ": "ا",
    "ى": "ي", "ة": "ه", "ؤ": "و", "ئ": "ي",
    # people type with persian/urdu keyboards sometimes
    "ک": "ك", "ی": "ي",
})


def normalize(text: str) -> str:
    """Lowercase, strip arabic diacritics and unify letters so 'كلوركس' == 'كلوروكس'-ish."""
    if not text:
        return ""
    t = unicodedata.normalize("NFKC", text)
    t = _DIACRITICS.sub("", t).replace(_TATWEEL, "")
    t = t.translate(_ARABIC_MAP).lower()
    t = re.sub(r"[^\w\s]", " ", t)
    # drop the arabic definite article on each word, users type both ways
    t = " ".join(w[2:] if w.startswith("ال") and len(w) > 4 else w for w in t.split())
    return t.strip()
