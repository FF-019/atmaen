from datetime import datetime, timezone


def utcnow() -> datetime:
    # the db columns are naive, so strip tzinfo after taking aware utc time
    return datetime.now(timezone.utc).replace(tzinfo=None)
