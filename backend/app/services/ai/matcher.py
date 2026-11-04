"""
Text recognition: find which chemical the parent means.

The index is rebuilt when the chemical table changes (admin edits). It's small
enough (hundreds of rows) to keep in memory and fuzzy match every request.
"""

from dataclasses import dataclass
from threading import Lock

from rapidfuzz import fuzz, process
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Chemical
from app.services.ai.normalize import normalize

MATCH_THRESHOLD = 82
CANDIDATE_THRESHOLD = 72


@dataclass
class MatchResult:
    chemical_id: int | None
    score: float
    candidates: list[tuple[int, float]]


class ChemicalIndex:
    def __init__(self):
        self._names: list[str] = []
        self._ids: list[int] = []
        self._lock = Lock()
        self.dirty = True

    def rebuild(self, db: Session):
        names, ids = [], []
        for chem in db.scalars(select(Chemical)):
            terms = [chem.name_en, chem.name_ar]
            if chem.aliases:
                terms += [a for a in chem.aliases.split(",") if a.strip()]
            for term in terms:
                n = normalize(term)
                if n:
                    names.append(n)
                    ids.append(chem.id)
        with self._lock:
            self._names, self._ids = names, ids
            self.dirty = False

    def match(self, db: Session, text: str) -> MatchResult:
        if self.dirty:
            self.rebuild(db)

        query = normalize(text)
        if not query or not self._names:
            return MatchResult(None, 0, [])

        hits = process.extract(query, self._names, scorer=fuzz.WRatio, limit=12)

        # several aliases point to the same chemical, keep the best score per id
        best: dict[int, float] = {}
        for _name, score, idx in hits:
            cid = self._ids[idx]
            best[cid] = max(best.get(cid, 0), score)

        ranked = sorted(best.items(), key=lambda x: x[1], reverse=True)
        top_id, top_score = ranked[0]

        candidates = [(cid, s) for cid, s in ranked[:4] if s >= CANDIDATE_THRESHOLD]
        if top_score >= MATCH_THRESHOLD:
            # if the second one is almost the same score it's ambiguous,
            # better to ask the parent than to guess
            if len(ranked) > 1 and ranked[1][1] >= top_score - 2 and ranked[1][1] >= MATCH_THRESHOLD:
                return MatchResult(None, top_score, candidates)
            return MatchResult(top_id, top_score, candidates)
        return MatchResult(None, top_score, candidates)


index = ChemicalIndex()
