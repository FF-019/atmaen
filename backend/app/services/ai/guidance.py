from app.models import Chemical, Child
from app.schemas.case import Guidance, Step
from app.schemas.chemical import ChemicalOut
from app.services.ai import protocols as P


def _bump(severity: str, to: str) -> str:
    order = P.SEVERITY_ORDER
    return to if order.index(to) > order.index(severity) else severity


def severity_from_symptoms(base: str, symptoms: list[str]) -> str:
    sev = base
    for code in symptoms:
        weight = P.SYMPTOMS.get(code, (None, 0))[1]
        if weight >= 3:
            sev = _bump(sev, "critical")
        elif weight == 2:
            sev = _bump(sev, "high")
        elif weight == 1:
            sev = _bump(sev, "moderate")
    return sev


def build_guidance(
    chemical: Chemical | None,
    category: str | None = None,
    confidence: float = 0.0,
    child: Child | None = None,
    symptoms: list[str] | None = None,
    candidates: list[Chemical] | None = None,
) -> Guidance:
    symptoms = [s for s in (symptoms or []) if s in P.SYMPTOMS and s != "none"]

    cat = chemical.category if chemical else (category or "unknown")
    proto = P.PROTOCOLS.get(cat, P.PROTOCOLS["unknown"])

    base = proto["base_severity"]
    if chemical:
        # the chemical's own hazard level can push it up, never down
        base = _bump(base, chemical.hazard_level)
    severity = severity_from_symptoms(base, symptoms)

    proto_icons = {icon for _, icon in proto["steps"]}
    # skip a generic first step if the protocol already has its own version of it
    raw_steps = [st for st in P.FIRST_STEPS if st[1] not in proto_icons] + list(proto["steps"])

    if cat == "button_battery" and child is not None and child.age_months >= 12:
        allergies = (child.allergies or "").lower()
        if "عسل" not in allergies and "honey" not in allergies:
            raw_steps.insert(3, P.HONEY_STEP)

    if chemical and chemical.extra_steps_ar:
        for line in chemical.extra_steps_ar.splitlines():
            if line.strip():
                raw_steps.insert(len(raw_steps) - 1, (line.strip(), "info"))

    call_now = severity == "critical"
    if call_now:
        # put the call first, nothing else matters before it
        raw_steps.insert(0, ("اتصل بالإسعاف 997 الآن وشغّل مكبر الصوت وتابع الخطوات", "phone"))

    steps = [
        Step(order=i + 1, text=text, icon=icon, warning=(icon in ("phone", "hospital") and call_now))
        for i, (text, icon) in enumerate(raw_steps)
    ]

    do_not = P.UNIVERSAL_DO_NOT + proto["extra_do_not"]
    watch_for = list(dict.fromkeys(proto["watch_for"] + P.RED_FLAGS[:2]))

    headline = proto["headline"]
    if chemical:
        headline = f"{chemical.name_ar}: {headline}"

    speech = _speech_text(headline, steps, call_now)

    return Guidance(
        matched=chemical is not None,
        confidence=round(confidence, 2),
        chemical=ChemicalOut.model_validate(chemical) if chemical else None,
        candidates=[ChemicalOut.model_validate(c) for c in (candidates or [])],
        severity=severity,
        call_emergency=call_now,
        headline=headline,
        do_not=do_not,
        steps=steps,
        watch_for=watch_for,
        speech_text=speech,
        disclaimer=P.DISCLAIMER,
    )


def _speech_text(headline: str, steps: list[Step], urgent: bool) -> str:
    # this is what the app reads out loud. short sentences, numbers spelled
    # as words read better with the arabic TTS voices we tested
    ordinals = ["أولاً", "ثانياً", "ثالثاً", "رابعاً", "خامساً", "سادساً", "سابعاً", "ثامناً"]
    parts = ["انتبه. " + headline + "." if urgent else headline + "."]
    for i, s in enumerate(steps[:8]):
        parts.append(f"{ordinals[i]}، {s.text}.")
    return " ".join(parts)
