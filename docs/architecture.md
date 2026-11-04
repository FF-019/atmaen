# Architecture

```
 ┌──────────────┐  HTTPS / WS   ┌───────────────────────────┐      ┌────────────┐
 │ Flutter app  │ ────────────▶ │ FastAPI                   │ ───▶ │ MySQL      │
 │ parent /     │               │  auth, children, cases    │      └────────────┘
 │ volunteer    │ ◀──────────── │  ai, consultations (+ws)  │      ┌────────────┐
 └──────┬───────┘   bundle      │  volunteers, education    │ ───▶ │ AI module  │
        │                       │  hospitals, offline, admin│      └────────────┘
 ┌──────▼───────┐               └─────────────▲─────────────┘
 │ SQLite on    │                             │
 │ the phone    │               ┌─────────────┴─────────────┐
 └──────────────┘               │ React admin dashboard     │
                                └───────────────────────────┘
```

## Data model

Follows the ERD in the project report (chapter 5.2.6), with a few additions made during implementation:

- `users` holds parents, volunteers and admins (role column). Volunteer fields (specialty,
  institution, license, verified, available) live on the same table, matching the class diagram where
  Volunteer extends User.
- `children` belong to a parent. Age is computed from `birth_date` so it never goes stale.
- `chemicals` + `products`: the report had a barcode on the chemical; in practice one chemical
  (sodium hypochlorite) is sold in many products with different barcodes, so products got their own table.
- `emergency_cases` link a child to a chemical, with the input method, symptoms, severity and GPS.
- `ai_results` keep what the AI returned for every analysis (also anonymous ones, `case_id` null).
- `consultations` + `consultation_messages`.
- `educational_resources`, `hospitals`, `audit_logs`.

## How guidance is built

`app/services/ai/guidance.py`

1. Resolve the chemical (text matcher, barcode lookup, or image category).
2. Pick the protocol for its category from `protocols.py`. Unknown substance → the cautious "unknown" protocol.
3. Severity = max(protocol base, chemical hazard level), then raised by reported symptoms
   (breathing, seizure, unconscious → critical).
4. Steps = generic first steps + protocol steps + substance-specific extra steps.
   Age-specific steps (honey for button batteries, only over 12 months) are added here.
5. Critical → "call 997" becomes step 1 and the app reads the steps aloud automatically.

The same logic (minus age-specific steps) runs on the phone from the offline bundle, so the app gives a
safe answer with no connection.

## Text matching

`normalize()` strips diacritics and tatweel, unifies alef/hamza forms, ta marbuta and ya, removes the
definite article, then RapidFuzz `WRatio` scores the query against every name and alias. Scores ≥ 82 match;
if the runner-up is within 2 points it's treated as ambiguous and the parent picks from candidates.

## Image model

MobileNetV2 with ImageNet weights, a new softmax head per protocol category, trained in two stages
(frozen base, then the top 30 layers unfrozen at a low learning rate). See `scripts/train_image_model.py`.
TensorFlow is optional at runtime; without it the endpoint answers with the generic steps.

## Live chat

Messages are sent with `POST /consultations/{id}/messages` so they're stored even on a flaky connection,
then broadcast to the room over a WebSocket. The app also polls every 8 seconds in case the network
blocks WebSockets. The hub is in memory, which is fine for one API instance; running several workers
needs Redis pub/sub.

## Security

- bcrypt password hashes, JWT with role claim, role checks on every route
- parents only see their own children and cases; a volunteer sees a case only after accepting it
  (or as a pending request once verified)
- disabled accounts lose access immediately, even with a valid token
- audit log for logins, failed logins and admin changes
- CSV exports contain no names or locations
