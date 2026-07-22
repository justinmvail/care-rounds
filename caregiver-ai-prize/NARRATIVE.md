# Care Rounds — ACL Caregiver AI Prize, Phase 1

**Track 2 — AI Tools for Extending the Caregiver Workforce**

> Assembled submission narrative (cover + abstract + Sections 1–5 in the ACL
> application outline's official order). Content mirrors the working section
> files `00`–`05`. `[FOUNDER: …]` markers must be filled before submission;
> `[VERIFY: …]` markers must be confirmed against the cited source. Final step:
> convert to a 508-compliant PDF/Word (≥11pt body, 1-inch margins, page numbers
> on the narrative, no gov logos).

---

## Cover Page

**Solution name:** Care Rounds
**Team / organization:** JCSV One LLC, doing business as **Juno Code Studio**
**Track:** **Track 2 — AI Tools for Extending the Caregiver Workforce**
**Primary contact:** [FOUNDER: full legal name] · [FOUNDER: email] · [FOUNDER: phone] · U.S. citizen / permanent-resident status: [FOUNDER: attest]
**Alternate contact (optional):** [FOUNDER: name/email/phone, or "N/A — solo entrant"]
**Team members & affiliations:** Solo entrant — [FOUNDER: name], Founder & Developer, JCSV One LLC (Juno Code Studio). Planned Phase-2 direct-care-worker and home-care-agency advisors to be secured through partnerships (see Appendix).
**Meritorious prize focus area (optional):** [FOUNDER: confirm/keep or drop — see Section 5.]

## Abstract (≤250 words)

The paid direct-care workforce — home health aides, personal care aides, and
direct support professionals — is the fastest-growing occupation in the country
and one of the most strained. Roughly 4.8 million workers earn near-minimum
wages, turn over at rates commonly reported between 40% and 65% a year, and spend
a large share of every shift on documentation, scheduling churn, and coordination
instead of care. Agencies cannot hire their way out; the only leverage is
efficiency and well-being *per worker*.

Care Rounds is an AI care-operations app for direct-care teams. Its flagship is
**ambient visit documentation** — the aide talks through a visit and the AI writes
a structured, reviewable note, turning the day's heaviest paperwork into a few
spoken sentences. Around it sits a **client-grounded AI coach** for the specific
person in front of the worker, with a code-side **escalation path to a
supervisor**; **explainable early-warning flags** (repeated falls, a medication
running low) surfaced from the data the worker already enters; and an
**AI-guided care-plan checklist**. A persistent client switcher, a cross-client
"today's visits" view, and a supervisor-flag inbox organize a real caseload — a
route of several clients a day, the way aides actually work.

Care Rounds shares its architecture and safety design with Holdclose (our Track 1
entry): human-in-the-loop confirmation on every change, a non-diagnostic coach
that flags uncertainty, and an open-weight model on our own cloud so care data
never reaches a separate AI vendor. It is a working, tested application today —
built to return caregiving time to the workforce.

---

# Section 1 — Understanding of Need and Solution Design

## The need: a workforce in crisis, drowning in administrative time

Most families who need help at home rely on a paid direct-care worker — a home
health aide (HHA), personal care aide (PCA), or direct support professional (DSP).
This is the workforce that lets an aging or disabled person stay in their own home
instead of an institution, and it is in a slow-motion collapse.

- It is **enormous and growing fastest of all.** There are roughly **4.8 million
  direct-care workers** [VERIFY: PHI]. The U.S. Bureau of Labor Statistics
  projects **home health and personal care aides to add more new jobs than any
  other occupation this decade**, with hundreds of thousands of openings every
  year — the large majority just to replace workers who leave.
- It is **underpaid and unstable.** Median pay sits near **$16/hour** (BLS), and
  annual caregiver **turnover is commonly reported between roughly 40% and 65%**,
  higher at some agencies [VERIFY: PHI / Home Care Pulse]. Agencies spend enormous
  effort recruiting and re-training instead of delivering care.
- The demand behind it is the same demand Track 1 addresses: an estimated **63
  million** Americans care for an aging or ill loved one, and many lean on paid
  workers to survive it.

Agencies **cannot hire their way out of this** — the labor pool is finite, wages
are constrained by thin reimbursement, and the population needing care is climbing.
The only durable levers are **efficiency per worker** (returning hours lost to
paperwork and coordination back to care) and **worker well-being and retention**
(making the job less isolating and frustrating so people stay).

**Where the hours go.** A direct-care worker's day is not one client; it is a
route of several short visits across different homes — the industry's own
"rounds." Across that day, a large share of the worker's time is not care. It is
**documentation** (every visit must be written up — the heaviest, most-hated
recurring task, usually done from memory at the end of a shift), **coordination**
(which client is next, what changed, when to pull in a nurse), and **watching for
early warning signs** with no tooling, so problems become crises before anyone
notices. Reducing that load — *without* adding another compliance chore — is the
highest-leverage thing software can do for this workforce.

## The solution: an AI care-operations app for the direct-care team

Care Rounds is a mobile app (iOS + Android) for the paid direct-care team. Where
our Track 1 product, Holdclose, serves the *family* caregiver of one loved one,
Care Rounds serves the *paid worker and their agency* across a caseload of many
clients — same product DNA and safety design, pointed at the workforce. The AI
does four things, each aimed at the hours identified above, and all four are built
and working today:

1. **Ambient visit documentation — the flagship ("the note that writes itself").**
   The worker taps *Document visit* and simply **talks** a quick account of the
   visit; the AI turns it into a **structured, reviewable visit note** (summary,
   observations, tasks completed, anything to flag) with zero typing. Nothing
   saves until the worker reviews it. (ACL Track-2 use case #2, *Documentation*.)
2. **A client-grounded AI coach, with a path to a human.** A coach grounded in the
   selected client's real care data answers in-the-moment questions, and a
   **code-side (non-LLM) watchdog escalates to a supervisor** when something
   concerning appears. (Use cases #4 *Real-time coaching*, #7 *Data aggregation*.)
3. **Explainable early-warning ("predictive care-need") flags.** Rule-based,
   explainable signals from the data the worker already enters — a repeated-falls
   trend, a medication running low — each stating the plain reason it fired.
   No black-box model, no new hardware. (Use case #5, *Predictive analytics*.)
4. **AI-guided care-plan checklist.** The AI proposes concrete visit tasks grounded
   in the client's profile; the worker approves the ones that fit into the
   client's routine. Human-in-the-loop always. (Use cases #4 / #9.)

Organizing this is a workforce-shaped information architecture: a **persistent
client switcher**, a **"Today's visits"** view that leads Home with the worker's
route across every client (one in progress *now*, with a *Start visit* action),
a **My Rounds** cross-client day, a **Team** hub (client roster, caregivers,
shifts, assignments), and a **supervisor-flag inbox**.

**Scope discipline.** Care Rounds is **not** an EVV product (its light check-in/out
is *time-saved*, never compliance), **not** billing/claims/payroll, **not** a
scheduling-optimization engine, **not** an ATS/hiring tool, and **not** remote
hardware monitoring. Every feature meets one test: *does it reduce a worker's
burden through AI, or just match an incumbent's checklist?*

**A clear role boundary on appointments.** Consistent with the industry, the
frontline aide does **not** schedule medical appointments — that is a coordinator
or family function; the aide's role is to know about a visit, prep, arrange
transport, and take notes at it. Appointment *creation* belongs on the family side
(our Track 1 product, Holdclose), and a planned **cross-product connection** would
surface a family-created appointment **read-only** to the assigned worker in Care
Rounds. Two products, one shared care circle, each matched to its real-world role.

## End-user input and how it shaped the design

[FOUNDER: User-Centered evidence — fill from your field feedback as concrete
"input → change" links (who, by role and with consent; what they said; what Care
Rounds changed). Two examples already true of the build: (a) a day of visits was
rebuilt from a thin single-client model into a **route of multiple clients a day,
seeing some twice (morning and evening)** after grounding it against how aides
actually work; (b) appointment *management* was reconsidered and removed after
confirming that **booking is a coordinator's job, not the aide's**, reframed to
read-only awareness fed from the family side. Add your own documented sessions and
secure consent-to-cite.]

---

# Section 2 — Implementation Approach

**Technology readiness — a working, tested product.** Care Rounds is a real
application: built in **Flutter**, running on **iOS and Android** from one
codebase, backed by an automated suite of **~1,900+ tests** (widget, golden,
provider, integration) that passes green plus clean static analysis, with a
visual-regression golden on every screen. That puts it at **TRL 3+** — concept
feasibility demonstrated in a working build with the critical technical elements
implemented and exercised. Care Rounds is a **fork of the same architecture** as
our Track 1 product, Holdclose, re-pointed to the workforce — a deliberate
platform-maturity advantage: two products on one proven, tested spine.

**Honest deployment status.** Today Care Rounds installs as signed builds on real
devices. It is **not yet in the app stores** — store release is a
submission-and-approval step gated on organization enrollment (JCSV One LLC), not
remaining engineering. The production backend + billed inference path and agency
onboarding are Phase-2 build items.

**Architecture and the AI.** The coach's guidance is assembled from the selected
client's real care data (medications, routines, visit history, care circle) and
run through the model. In production the AI runs on **Cloudflare Workers AI — an
open-weight model on our own cloud** — so client data used to ground the coach
**never goes to a separate AI vendor**; the backend is a **Cloudflare Worker** over
**D1** and **R2**. Every AI feature sits behind an interface with a deterministic
fake for tests, and every real call routes through one gatekept endpoint so
per-user quotas and a global spend cap apply. Database migrations are written to be
**safe to run twice**, pinned by tests.

**Safety and evaluation.** Care Rounds shares Holdclose's model-independent
responsible-AI harness: **human-in-the-loop confirmation on every care-data
change** (the visit note is reviewed before saving, the checklist approved
task-by-task, a flag resolved by a human), a **non-diagnostic, uncertainty-flagging
coach**, and a **code-side (non-LLM) crisis watchdog**. Holdclose's **41-cycle Data
Output Logs (41/41 guardrails held)** validate this shared stack; the guardrails
are structural and identical here. [FOUNDER: optionally re-run the harness against
the Care Rounds coach for a Track-2-specific log.]

**Impact metric — care returned + escalations handled.** Phase 2 would measure
**documentation time per visit** (before vs. with ambient documentation),
**coach-assisted resolutions that avoided a supervisor call** plus **escalation
precision/recall**, **early-warning lead time**, and **worker-reported burden and
retention**, stated as a measurement plan on real usage, not fabricated numbers.

**Phase 2 (2026–2027).** (1) Recruit a home-care agency or worker co-op as a design
+ pilot partner. (2) Stand up Care Rounds' own production backend (Worker + D1 +
R2, real Google auth, billed inference with spend caps) and complete app-store
release. (3) Run a structured pilot; instrument the metrics; iterate the prompts
and escalation thresholds from observed data (evaluation → adaptation). (4) Build
agency onboarding + the business model (the buyer is the agency, not the worker)
and the Holdclose↔Care Rounds connection for read-only cross-product awareness.
(5) Re-run and publish the Data Output Logs.

**Team.** [FOUNDER: solo founder/developer — name, background (U.S. Air Force
veteran; a decade in VA benefits systems; lived caregiving experience), role, and
any Phase-2 advisors secured through partnerships.]

---

# Section 3 — Usability and Integration

**Designed for the real conditions of the job.** A direct-care worker uses a phone
one-handed, between tasks, in someone's home, often at shift's end. Care Rounds is
**voice-first where it matters most** (the visit note is done by talking, via a
center mic on every screen); keeps a **persistent client bar** so "whose 8am meds
are these?" is never ambiguous (a safety property); **leads the day with today's
visits** across clients with a one-tap *Start visit*; and uses **large targets,
calm layout, and plain language** grouped by task.

**Error prevention by design, not warnings.** Nothing changes care data without a
deliberate confirmation — the visit note is reviewed and edited before saving, the
AI-suggested tasks approved one at a time, destructive actions confirmed in-thread.
The AI **proposes; the worker disposes.** Weak data is **flagged, not guessed**.

**Transparency and empowerment, not replacement.** The coach's guidance is grounded
in and refers to the client's own data, so the worker sees why; the AI automates
the paperwork and the watching so the worker spends **more** time in care and human
contact, and the **supervisor-flag channel keeps a human in the loop** for anything
that matters. The vendor/model is never named in the interface; the capability is
plain, the judgment stays with the worker.

**Realistic-conditions testing.** Care Rounds is exercised with integration flows,
a golden test on every screen, deterministic AI fakes, and a **rich realistic demo
dataset** — a full caseload of multiple clients, a signed-in worker, a day of
cross-client visits, per-client medications with real refill runways, and open
supervisor flags. [FOUNDER: Phase-2 adds testing with real workers in real homes —
via the agency pilot.]

**Integration and interoperability.** Care Rounds slots into the aide's actual day
(rounds → visit → note → flag) rather than adding a compliance chore, and
deliberately integrates *around* the incumbent systems (EVV, billing, scheduling)
rather than replacing them. Because Care Rounds and **Holdclose share a care-data
spine**, a planned **cross-product connection** lets a **family-scheduled
appointment (Holdclose) surface read-only to the assigned worker (Care Rounds)** —
concrete interoperability matched to each role, and a coherent "whole care team"
picture: the same loved one, served by family and paid workforce on one connected
care circle. A shareable **care-summary handoff** already exists as the seed of
EHR/agency-system interoperability (a Phase-2 roadmap item, not an overclaim).

**Accessibility.** OS Dynamic Type support with an in-app text-size control, simple
linear flows, a warm high-contrast palette, semantic labeling on interactive
controls, WCAG-AA hardening in progress — core requirements for a time-pressed,
often-multilingual workforce.

---

# Section 4 — Alignment with the Caregiver AI Principles

Care Rounds was designed around ACL's seven Caregiver AI Principles; each is met by
a real, working feature.

**1. Protect privacy, dignity, and choice.** Client data is per-client and
portable; **assignments govern who can see which client**; traffic is TLS-encrypted
in transit; the device DB sits on OS device encryption with OS cloud backups
disabled; server data is on Cloudflare D1/R2; and **the AI runs on Cloudflare
Workers AI (open-weight, our own cloud)** so client data **never reaches a separate
AI vendor**. We do not sell care data. The person receiving care is "your client";
the worker is a professional whose time and judgment the product respects.

**2. Support human-in-the-loop accountability.** The visit note is reviewed before
it saves; the checklist is approved task-by-task; every care-data change confirms;
the coach is grounded in the client's own data; weak data is flagged and escalated
to a supervisor rather than asserted; and the **supervisor-flag inbox** is the human
hand-off made explicit — a flag is a task *for a person*, never auto-closed.

**3. Support caregivers' well-being and reduce burden.** Care Rounds' whole purpose
is to return time to a strained, high-turnover workforce: ambient documentation
kills the heaviest task, the coach cuts the "who do I call" stress, early-warning
flags reduce frightening crises, and the rounds view removes multi-client friction.

**4. Supplement, not replace, human connection.** By automating the admin and the
watching, Care Rounds gives the worker **more** time *with* the client; the Team
layer and supervisor channel connect an otherwise-isolated frontline worker to
people; the escalation path routes concerns to humans.

**5. Allow personalized and flexible care.** Guidance and suggestions are grounded
in the specific client's situation, and the whole app re-centers on whoever the
worker is with — not a single-diagnosis or one-size template.

**6. Promote safety, reliability, and transparency.** Transparent, non-diagnostic,
uncertainty-flagging coach; structural, model-independent guardrails (code-side
crisis watchdog, human-in-the-loop confirmation, model-agnostic architecture);
**explainable rule-based** early-warning signals (not a black-box score); and the
shared **Data Output Logs** (41/41 guardrails held — dose-change, diagnosis,
prompt-injection, unknown-protocol probes all refused; crisis referral fires
independent of the model).

**7. Ensure affordability and access.** The workforce and its agencies run on thin
margins, so affordability *is* the adoption question. Care Rounds runs on the phone
the worker already carries (no new hardware), the open-weight self-hosted model
keeps inference cost low enough to price for thin-margin agencies, the local-first
design works with limited connectivity, and every inference call is metered behind
quotas + a global cap. [FOUNDER: state the pricing commitment — e.g. transparent,
low per-seat rate to agencies; no cost to the individual worker.]

---

# Section 5 — Meritorious Prize Eligibility (Optional)

[FOUNDER: **Optional.** Confirm the Track-2 meritorious focus areas on the current
ACL site, then keep the strongest candidate below **only if** it is evidence-backed
(a matching pilot partner or a matching user in your documented feedback);
otherwise delete Section 5.]

- **A. Rural / underserved-area workforce.** The shortage is most acute outside
  metro areas; Care Rounds' local-first design works with limited connectivity, runs
  on the phone the worker already carries, and its low self-hosted inference cost is
  priceable for the thin-margin agencies serving rural communities.
- **B. The DSP workforce serving people with IDD.** Care Rounds is diagnosis-agnostic
  — it centers on the worker's tasks and the client's real data — so it serves DSPs
  supporting people with intellectual/developmental disabilities as naturally as
  aides for older adults.

Any meritorious framing stays within the non-diagnostic, human-in-the-loop
boundaries: Care Rounds coaches and supports the worker and documents the visit — it
never diagnoses or makes a care decision about the client.
