# Care Rounds — Product Design (ACL Caregiver AI Challenge, Track 2)

**Track 2: AI Tools for Extending the Caregiver Workforce.** Care Rounds
reuses the Care Rounds/Holdclose care-management + AI-coach spine, changing
the *relationships* — not the features — so one **team** of paid direct-care
workers can manage **many clients**, with the AI coach and documentation tools
pointed at the worker instead of the family member.

> Design constraints (owner): **minimum change from the existing codebase;
> maximize reuse.** The core change is (1) make loved-one↔caregiver
> **many-to-many**, (2) group caregivers into **teams**, (3) reframe **shifts**
> as worker×client×time, and (4) match the UI. Keep the UI visually close to
> current for now; originality pass comes later.

---

## 1. The thesis (Understanding of Need)

The direct-care workforce (home health aides, personal care aides, DSPs) is in
crisis: very high annual turnover, thin margins, and workers who spend a large
share of their day on **administrative overhead** (documentation, EVV,
scheduling churn, missed/duplicated visits) instead of care. Agencies and
home-care co-ops can't hire their way out; the leverage is **efficiency per
worker** and **worker well-being/retention**.

Care Rounds is an **AI-enabled care-operations app for direct-care teams**. It:
- gives each worker a **data-grounded AI coach** for the specific client in
  front of them (real-time guidance, visit prep, "what changed since last
  visit"), with a code-side escalation path to a supervisor;
- **cuts documentation to near-zero** via voice → structured visit notes;
- keeps **matching, scheduling, and the worker's daily "rounds"** in one place;
- surfaces **predictive care-need/risk flags** from visit + health data.

Same product DNA as Track 1 (Holdclose), aimed at the **worker + agency**
rather than the family. (Track-2 workforce-crisis evidence:
`caregiver-ai-prize/` packet, `ancor_dsw_crisis_2025.pdf`.)

---

## 2. Mapping to ACL's nine Track 2 use cases

ACL lists nine example applications. Care Rounds credibly addresses **eight**
(all but hardware sensors), most by **reuse**:

| # | ACL use case | Care Rounds | Source |
|---|---|---|---|
| 1 | **Matching & scheduling** — match workers to clients by skill/location/availability, adjust to reduce missed shifts/overtime | **Care Rounds** = a worker's daily rounds; shifts become worker×client×time; assignment roster; coverage/gap view | Extend existing `shifts`, `calendar`, `tasks`, `care_shift` |
| 2 | **Documentation** — voice notes → structured docs | **Ambient visit documentation — the note that writes itself.** Voice at the point of care → a structured visit note (health log / journal wizard / care-plan update) with zero typing | Reuse voice intake, `journal_wizard`, `health_log`, `visit_prep` |
| 3 | **Training** — short, role-specific modules | Reframe **Learn** playbooks as role/experience-level micro-training + refreshers | Reuse `community/learn` |
| 4 | **Real-time coaching** — step-by-step guidance, flag supervisory support | **The AI coach**, grounded in *that client's* data; code-side crisis watchdog escalates to supervisor | Reuse `chat_service` + `chat_context_builder` + crisis watchdog |
| 5 | **Predictive analytics** — predict rising need / fall / hospitalization risk | Pattern detector + refill-runway + health-log trends → **care-need/risk flags** | Reuse `pattern_detector`, `medication_supply` |
| 6 | Remote monitoring (sensors) | **Out of scope** (no hardware); note as roadmap/interoperability | — |
| 7 | **Data aggregation** — combine notes + environment for care visibility | `chat_context_builder` already aggregates the full care picture per client | Reuse |
| 8 | **Workforce management** — forecast staffing, coverage, turnover risk | Coverage/gap view over shifts; open-shift surfacing | Extend `shifts`/`calendar` |
| 9 | **Administrative automation** — time tracking, billing, compliance, quality | Lightweight shift check-in/out **framed as time-saved** (not an EVV product), **care-summary PDF** handoff | Reuse `pdf_exporter`; extend shifts |

The flagship AI is #2 + #4: **ambient visit documentation — the note that
writes itself** — plus **a coach that already knows the client**. Those are the
two things a direct-care worker feels every visit, and both are pure
AI-innovation / burden-reduction (the contest's thesis), not incumbent parity.

---

## 2a. Strategy lock & non-goals (the thesis guardrail)

This is the fixed point every feature decision is checked against. It exists
because the fastest way to lose Track 2 is to drift into feature-parity with
the incumbents (AlayaCare, AxisCare, WellSky, CareSmartz360) — matching their
checklists dilutes the AI-innovation story the judges are actually scoring.

**What we ARE (the wedge):**
- **Ambient documentation** — the flagship. Talk during/after a visit; the app
  produces the structured note. Judged under Documentation (#2) + Burden
  Reduction (Principle 3).
- **A client-grounded AI coach** with a supervisor escalation path (#4).
- **Predictive care-need / risk flags** from visit + health trends (#5).
- **AI-guided care-plan task checklist** per client/visit (#4/#9).
- Everything else (rounds, roster, assignments, care-summary handoff) is
  **supporting connective tissue**, not a headline.

**What we are explicitly NOT (anti-goals — do not build, do not claim):**
- **NOT an EVV product.** No EVV certification, no state-aggregator
  integration, no Cures-Act-compliant verification. Check-in/out exists only as
  a *time-saved* convenience; it is never framed or sold as EVV. (EVV is
  commodity, non-AI, regulation-owned, and incumbent territory — a parity trap.)
- **NOT billing / claims / payroll.** No invoicing, no claim submission, no
  pay runs. The care-summary PDF is a clinical/handoff artifact, not a bill.
- **NOT a scheduling-optimization engine.** We show a worker's rounds and
  coverage gaps; we do not solve the staffing-optimization / route-optimization
  problem the incumbents compete on.
- **NOT an ATS / hiring / credentialing system.**
- **NOT remote hardware monitoring** (sensors, #6) — interoperability roadmap
  only, no hardware.

**The test for any new feature:** does it *reduce a worker's burden through AI*,
or does it just *match an incumbent's checklist*? Build the first; roadmap or
drop the second.

---

## 3. The data-model change (the whole point — kept minimal)

### What exists today
- `PatientsTable` is **single-row** ("one loved one per install"); an
  `active-patient` settings pointer already exists.
- Every care table (`MedicationsTable`, `DoseWindowsTable`,
  `AppointmentsTable`, `HealthLogEntriesTable`, `CarePlanRoutinesTable`,
  `EmergencyCardsTable`, docs…) is **already keyed by `patientId`** — the data
  is per-client already; only the *constraint* says there's one.
- Care Circle already models **members** (`care_circle_membership`, with
  roles), **shifts** (`care_shift`), **tasks** (`care_task`), calendar,
  activity, expenses, QR/scan join.

### The change (four things)
1. **Multi-client.** Drop the single-row assumption on `PatientsTable`; allow
   many **Clients**. The `active-patient` pointer becomes the **client
   switcher**. Most repositories already filter by `patientId` — they stop
   assuming "the one patient" and read the selected client. *(Largest lift, but
   the schema already carries the key everywhere.)*
2. **Team.** Promote **Care Circle → Team**: today a circle is scoped to one
   loved one; a Team owns **many clients** and **many caregivers**. Reuse
   `care_circle_membership` for team membership + roles (add a
   `supervisor`/`admin` role alongside `caregiver`).
3. **Many-to-many assignment.** New join: **`assignments (caregiver_id,
   client_id, …)`** — which workers serve which clients. This is the M:N
   relationship the owner called out. Drives who sees which client and who can
   be scheduled.
4. **Shift = worker × client × time.** Extend `care_shift` to reference a
   **client** (and optional check-in/out timestamps). A worker's list of
   shifts *is* their "rounds."

Everything downstream of `patientId` (meds, appointments, health log, coach
grounding) **works unchanged** once "the active patient" becomes "the selected
client."

### Backend (Cloudflare Worker) mirror
The circle sync already moves shared care data server-side. Extend the same
tables/endpoints with `team_id` + the `assignments` join; the sync sink and
`chat_context_builder` scope by selected client. No new architecture.

---

## 4. UI change (kept close to current)

Reuse every existing screen **per selected client**; add the minimum framing:

- **Client switcher** at the top of the shell (reuses the `active-patient`
  pointer) — pick which client you're working with; all four tabs (Home, Care,
  Chat, Community) then show that client, exactly as today.
- **Team hub** = today's **Care Circle hub** (`care_team_hub_screen`),
  relabeled and widened: roster of caregivers, roster of clients, assignments.
- **My Rounds** = today's **shifts/calendar** screens, filtered to *me* —
  my visits today across clients, with check-in/out and a jump into that
  client's coach.
- **Coach, scan-to-import, health log, meds, appointments, Learn** — unchanged
  screens, now scoped to the selected client.

No new visual language yet (owner: originality pass is a later phase). The
four-tab bar, `PathHeader` breadcrumbs, and brand tokens stay.

---

## 5. Reuse vs. new

**Reused essentially as-is:** the AI coach (`chat_service`,
`chat_context_builder`, crisis watchdog), voice intake, scan-to-import
(prescription/appointment — insurance-card scan dropped as off-thesis), health
log, medications + dose windows,
appointments + visit-prep, care-summary PDF, pattern detector, Learn, emergency
card, the four-tab shell, sync, auth, TTS.

**Changed (small):** `PatientsTable` single-row → multi; Care Circle → Team
(label + scope); `care_shift` gains a client ref + check-in/out; sync +
`chat_context_builder` scope by selected client.

**New (small):** `assignments` join table + provider/repo; client switcher
widget; roster/assignment views inside the Team hub; coverage/gap view over
shifts. That's the bulk of the build.

---

## 6. Mapping to the six Track 2 judging criteria

1. **Responsiveness to Need** — grounded in the direct-care workforce crisis
   (turnover, admin burden, missed visits); the solution returns *caregiving
   time* by removing documentation + scheduling friction, and supports
   well-being via the coach. Impact metric: **minutes of admin removed per
   visit** and **coach-assisted resolutions without a supervisor call**.
2. **User-Centered** — recruit **direct-care workers + one agency/co-op** for
   input and co-implementation (mirror Track 1's tester process; document it in
   a Care Rounds `FEEDBACK_LOG`). *This is the criterion that needs real
   worker/agency evidence — start recruiting now.*
3. **Implementation** — TRL-3+ today (working app, green suites); realistic
   Phase-2 pilot with one agency; metrics = admin-time saved, missed-shift
   rate, worker-reported burden, coach escalation correctness. Reuse Holdclose's
   **Data Output Logs** methodology (guardrail pass-rate, Smart-40, Protocol
   9-Delta) for the coach.
4. **Usability & Integration** — error-prevention by design (confirm cards on
   destructive actions), transparency (coach cites the client data it used),
   empowerment (flags a human, never auto-decides care); **integration** into
   the agency day; **interoperability** roadmap: EVV/EHR/scheduling export
   (care-summary PDF + NPI search exist today).
5. **Alignment with the 7 Principles** — see §7.
6. **Partnerships & Collaboration** — name an agency / home-care co-op / AAA /
   workforce org as a design + pilot partner (Appendix letters).

---

## 7. Alignment with the 7 Caregiver AI Principles

1. **Privacy/dignity/choice** — client data stays on the team's own
   infrastructure (Cloudflare Workers AI, open-weight model — no separate AI
   vendor); assignments gate who sees which client.
2. **Human-in-the-loop** — coach augments the worker; crisis watchdog +
   uncertainty clause escalate to a supervisor; destructive actions confirm.
3. **Well-being & burden reduction** — the core promise: less paperwork, less
   scheduling chaos, guidance in the moment → less burnout.
4. **Supplement not replace human connection** — automates the *admin* so the
   worker spends more time *with the client*, not less.
5. **Personalized & flexible** — coach is grounded per-client; assignments and
   rounds fit each worker's skills/availability.
6. **Safety/reliability/transparency** — non-diagnostic guardrails carry over
   verbatim; coach cites its data; Data Output Logs evidence.
7. **Affordability & access** — priced for thin-margin agencies; runs on
   commodity phones; open-weight model keeps inference cost low.

---

## 8. Build phasing (minimal-change order)

1. **Model:** multi-client (`PatientsTable`), `assignments` join, Team scope on
   membership, client ref on `care_shift`. Migrations safe-to-run-twice.
2. **Repos/providers:** scope by *selected client*; client-switcher provider
   off the existing `active-patient` pointer.
3. **UI framing:** client switcher in the shell; Team hub roster + assignments;
   My Rounds (filtered shifts) with check-in/out.
4. **Backend:** `team_id` + `assignments` on synced tables; scope sync +
   coach grounding by client.
5. **Reuse verification:** coach, scan, health log, meds, appointments run
   per-client unchanged; suites green; device build to confirm.
6. **Track-2 evidence (parallel, non-code):** recruit workers + an agency;
   Care Rounds `FEEDBACK_LOG`; partner letters; Data Output Logs re-run for the
   workforce framing.

---

## 9. Open decisions / risks

- **Scope creep vs. minimal change:** EVV/billing/compliance (#9) and workforce
  forecasting (#8) are deep incumbent domains and named **anti-goals** (§2a) —
  we take only the AI-innovation slice (ambient docs, coaching, risk flags) and
  a *time-saved* check-in/out, and explicitly roadmap/decline the rest rather
  than chasing parity.
- **Single-patient assumptions:** audit every `getPatient()`/`active-patient`
  caller when lifting the single-row limit — this is where reuse could bite.
- **Sensors (#6):** explicitly out of scope; frame as interoperability roadmap.
- **Two products, one team:** Care Rounds (Track 2) and Holdclose (Track 1)
  share DNA and a team — lean into that for the Partnerships/platform-maturity
  story; keep the entries and resources isolated (already done).

---

## 10. Implementation status (2026-07-18)

The Track-2 thesis (§2a) is built, green, and on `main`:

- **IA reframed for the workforce:** persistent client-switcher bar atop the
  shell; the Care tab grouped into sections; the four schedule surfaces
  consolidated into one segmented Schedule; a single client-management
  surface (Team → Clients + the switcher, Settings manager retired); Home
  leads with "Today's visits" across clients.
- **Flagship — ambient visit documentation:** talk/type → the AI structures a
  reviewable visit note → saved to the journal. Human-in-the-loop; guardrailed.
- **Supervisor escalation channel:** a flags inbox; the visit note auto-raises
  a flag when the AI marks a visit `needs_attention`; workers can raise one
  directly; a supervisor resolves.
- **Predictive early-warning:** an explainable, rule-based "Watch for" card
  (falls trend + refill runway) — no black-box model.
- **AI-guided care-plan checklist:** grounded task suggestions the worker
  approves into routines.

Every AI feature sits behind an interface with a deterministic fake (tests/
demo) and routes real inference through the same gatekept transport as the
coach. Off-thesis surfaces (consumer paywall, family expense-sharing,
insurance-card scan) were removed. Remaining Track-2 work is **non-code
evidence** (§8.6): worker/agency recruitment, partner letters, a Care Rounds
FEEDBACK_LOG, and the Data Output Logs re-run for the workforce framing.
