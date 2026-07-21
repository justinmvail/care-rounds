# Section 2 — Implementation Approach

> How Care Rounds is built, how ready it is, and how Phase 2 would validate and
> deploy it. `[FOUNDER: …]` = founder input required.

## Technology readiness: a working, tested product today

Care Rounds is **not a concept or a mockup — it is a working application.** It is
built in **Flutter** and runs on both **iOS and Android** from one codebase,
installs and runs on real devices, and is backed by an automated test suite of
**~1,900+ tests** (widget, golden/visual, provider, and integration tiers) that
passes green, plus static analysis kept clean. Every screen carries a
visual-regression "golden" test. This puts the solution at **TRL 3+** — concept
feasibility demonstrated in a working build, with the critical technical elements
(the grounded coach, the ambient-documentation pipeline, the risk detectors, the
multi-client data model) implemented and exercised.

Care Rounds is a **fork of the same codebase and architecture** as our Track 1
product, Holdclose, re-pointed from the family caregiver to the paid workforce.
That is a deliberate platform-maturity advantage: the two products share a proven
spine (the grounded AI coach, voice intake, scan-to-import, the care database,
sync, auth, the safety guardrails), so Care Rounds inherits a large amount of
already-built, already-tested infrastructure and the same responsible-AI design.

**Honest deployment status.** Today Care Rounds installs as **signed builds on
real devices** (used for the founder's own device testing). It is **not yet in
the app stores** — store release is a **submission-and-approval step gated on
organization enrollment (JCSV One LLC / Juno Code Studio)**, not remaining
engineering. The production backend + billed inference path and business
onboarding for agencies are **Phase-2 build items**, described below. We state
this plainly rather than overclaim availability.

## Architecture and the AI

- **Client-grounded coaching.** The coach's guidance is assembled from the
  **selected client's real care data** (medications, dose windows, routines,
  visit history, the care circle) via a context builder, then run through the
  model. Grounding in *that client* is the moat — it beats a blank chatbox.
- **Model-agnostic, self-hosted inference.** In production the AI runs on
  **Cloudflare Workers AI — an open-weight model on our own cloud
  infrastructure** — so client care data used to ground the coach **never goes to
  a separate AI vendor**. The backend is a **Cloudflare Worker** (Hono + Drizzle)
  over **D1** and **R2**. There is no third-party model provider in the data path.
- **Every AI feature sits behind an interface** with a deterministic **fake** for
  tests and demos and a real implementation for production, and every real
  inference call routes through the **same gatekept endpoint** (so per-user quotas
  and a global spend cap apply). This is how a solo team runs AI safely and
  affordably at scale.
- **The local database is per-client and portable**; the shared care-circle layer
  syncs server-side so a team sees the same picture. Database migrations are
  written to be **safe to run twice** (an idempotency discipline pinned by tests),
  because a bricked database is unrecoverable in the field.

## Safety and evaluation (the harness carries over)

Care Rounds shares Holdclose's **responsible-AI harness**, which is
**model-independent** because the guardrails are structural:

- **Human-in-the-loop on every change.** Every AI action that writes or changes
  care data routes through an explicit **confirmation** the worker must approve —
  in chat and in voice. The ambient visit note is *reviewed and edited* before it
  saves; the care-plan checklist is *approved task-by-task*; a supervisor flag is
  *resolved by a human*, never auto-closed.
- **Non-diagnostic, uncertainty-flagging coach.** The coach educates the worker;
  it does not diagnose the client, recommend or change a dose, or claim a
  prognosis. Its prompts forbid those, and it flags weak-data results rather than
  asserting.
- **A code-side (non-LLM) crisis watchdog** catches concerning content even if the
  model fails.
- **Data Output Logs.** Holdclose's **41-cycle Data Output Logs (41/41 guardrails
  held)** validate this shared stack. [FOUNDER: for Track 2, either cite the
  shared logs and note the guardrails are model-independent and identical here,
  or — stronger — **re-run the Smart-40 harness against the Care Rounds coach**
  (workforce prompts) and include a Care-Rounds-specific Data Output Logs
  document. This is an optional but high-value differentiator.]

## Impact metric: minutes of care returned, and escalations handled

The thesis is **efficiency and well-being per worker**, so the measurable outcome
is **administrative time removed per visit** and **coaching that resolves a
question without a supervisor call**. Concretely, Phase 2 would measure:

- **Documentation time per visit** — before vs. with ambient documentation
  (target: the day's heaviest task cut from minutes of typing to a spoken review).
- **Coach-assisted resolutions** that did *not* require a supervisor call, and,
  conversely, the **rate at which the escalation flag correctly routed a real
  concern to a human** (escalation precision/recall on a labeled set).
- **Early-warning lead time** — did a falls/refill flag surface before it became
  an incident?
- **Worker-reported burden and retention signal** over a pilot window.

These are stated as a **Phase-2 measurement plan on real usage**, not as
fabricated present-day numbers.

## Phase 2 (2026–2027) plan

1. **Recruit a home-care agency or worker co-op as a design + pilot partner**
   [FOUNDER: outreach in progress — see Appendix letters and `outreach_email.md`].
2. **Stand up the production backend** for Care Rounds — its own deployed
   Cloudflare Worker + D1 + R2, real Google auth for the Care Rounds app, and a
   **billed inference path with spend caps** — and complete **app-store release**
   under the enrolled organization.
3. **Run a structured pilot** with real aides across a real caseload; instrument
   the metrics above; iterate the ambient-documentation prompts and the
   escalation thresholds from the observed data (**evaluation → adaptation**).
4. **Build the agency onboarding + business model** (per-agency accounts, seats;
   the workforce buyer is the agency, not the individual worker) and the
   **Holdclose↔Care Rounds connection** for read-only cross-product awareness.
5. **Re-run the Data Output Logs** against the Care Rounds coach and publish.

## Team

[FOUNDER: Solo founder/developer — your name, background (U.S. Air Force veteran;
a decade inside VA benefits systems; lived caregiving experience), and role.
This is a §2 requirement (experience + affiliation + role). Note any Phase-2
advisors — an agency administrator, a direct-care worker, a home-care nurse —
that partnerships secure.]
