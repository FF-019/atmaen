"""
Write the offline bundle that ships inside the mobile app.
Run this after changing protocols or the chemical list:

    python -m scripts.export_offline_bundle ../mobile/assets/offline/bundle.json
"""

import hashlib
import json
import sys
from pathlib import Path

from app.api.offline import _bundle
from app.core.database import SessionLocal


def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "../mobile/assets/offline/bundle.json")
    with SessionLocal() as db:
        data = _bundle(db)
    version = hashlib.sha1(json.dumps(data, sort_keys=True, ensure_ascii=False).encode()).hexdigest()[:12]
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps({"version": version, **data}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"wrote {out} ({len(data['chemicals'])} chemicals, version {version})")


if __name__ == "__main__":
    main()
