# Care Rounds

**An AI care-operations app for the direct-care workforce — so aides spend their shift on care, not paperwork.**

Care Rounds is a mobile app (iOS + Android) for home health aides, personal care
aides, and direct support professionals — the fastest-growing and one of the most
strained occupations in the country. Workers spend a large share of every shift
on documentation and coordination instead of care, and agencies can't hire their
way out of the shortage. Care Rounds gives that time back **per worker**.

📱 iOS + Android · built by **Juno Code Studio** (JCSV One LLC)

> **Entry in the ACL / HHS Caregiver AI Prize Challenge — Track 2 (AI tools for
> extending the caregiver workforce).** **Dementia care is central to this
> workforce's day:** many home-care and direct-support clients live with
> dementia, and Care Rounds' ambient visit documentation, client-grounded
> coaching, supervisor escalation, and early-warning flags are built for aides
> supporting clients with dementia and other complex, high-acuity needs.

<!-- Screenshots: add 3–4 device captures here (Today's visits, Ambient visit note, Client coach, Supervisor flags). -->

## The flagship: ambient visit documentation

The aide **talks through a visit** and the AI writes a structured, reviewable
note — turning the day's heaviest paperwork into a few spoken sentences. The
worker reviews and edits before anything is saved. Nothing is filed from memory
at the end of a long shift.

## Built around a real caseload

Aides don't see one client a day — they run a route. Care Rounds is organized the
way they actually work:

- **Today's visits** — a cross-client view of the day's route, with a "Start
  visit" flow that focuses the app on the client in front of the worker.
- **Persistent client switcher** — always know, and change, whose care you're
  looking at.
- **Client-grounded AI coach** — practical, in-scope guidance for the specific
  person being cared for, grounded in that client's real care information.
- **Supervisor escalation** — a code-side path to flag something for a supervisor,
  with a supervisor-flag inbox, so concerns reach the right person quickly.
- **Explainable early-warning flags** — rule-based, reason-stating alerts
  (repeated falls, a medication running low) surfaced from the data the worker
  already enters — not a black-box score.
- **AI-guided care-plan checklist** — the plan for a visit, approved task by task.

## Responsible AI, by design

The guardrails are structural — they don't depend on which model is running:

- **Supports the worker; never diagnoses or prescribes.** The coach stays within
  an aide's scope, defers medical decisions to clinicians, and — when unsure —
  flags and escalates rather than guessing.
- **Human-in-the-loop on every change.** The ambient note is reviewed before it
  saves; care-plan tasks are approved individually; destructive actions never
  auto-execute.
- **The vendor is invisible.** The AI runs on our own cloud (an open-weight model
  on Cloudflare Workers AI), so client care data never reaches a separate AI
  vendor.
- **Validated.** Live safety cycles through the actual Care Rounds coach held
  every guardrail (dosing, diagnosis, prompt-injection, unknown-instruction, and
  crisis probes), backed by a code-side crisis watchdog and prompt sanitization
  pinned by the test suite.

## What it is *not*

Care Rounds is a care-quality and documentation tool, deliberately **not** an
electronic-visit-verification (EVV) system, a billing/claims/payroll platform, a
scheduling-optimization engine, or an applicant-tracking system. It complements
the systems an agency already runs.

## Under the hood

Flutter (Dart) · Riverpod · go_router · Drift (SQLite) · a Cloudflare Worker
backend (Hono + D1 + R2 + Workers AI). Care data is **local-first** and encrypted
at rest by the OS; team sync is authenticated and TLS-encrypted. Care Rounds
shares a tested backbone with **Holdclose**, our companion app for family
caregivers — two sides of one care team.

Care Rounds is an entry in the **ACL / HHS Caregiver AI Prize Challenge**
(Track 2 — AI tools for extending the caregiver workforce).

Quality is enforced by a large automated suite — **~1,900+ unit, widget, and
golden tests** plus a backend suite — run on every change.

## Development

```bash
flutter pub get
flutter test                 # full suite (unit + widget + golden)
flutter analyze
cd backend && npm test       # Cloudflare Worker suite
```

The app runs against a backend for auth and sync; a local development shim wraps
a CLI for dev-mode AI calls, so there are no API keys in source.

## License

© JCSV One LLC (Juno Code Studio). All rights reserved. The source is made
available for evaluation and is **not** licensed for reuse, redistribution, or
derivative works.
