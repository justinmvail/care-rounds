# Section 1 — Understanding of Need and Solution Design

> Track 2 — AI Tools for Extending the Caregiver Workforce.
> `[FOUNDER: …]` = founder input required. `[VERIFY: …]` = confirm the figure
> against the cited source (the ANCOR/PHI direct-care-workforce material in this
> packet) before final submission — do not ship an unverified number.

## The need: a workforce in crisis, drowning in administrative time

Most families who need help at home rely on a **paid direct-care worker** — a
home health aide (HHA), personal care aide (PCA), or direct support professional
(DSP). This is the workforce that lets an aging or disabled person stay in their
own home instead of an institution, and it is in a slow-motion collapse.

- It is **enormous and growing fastest of all.** There are roughly **4.8 million
  direct-care workers** in the U.S. today [VERIFY: PHI]. The U.S. Bureau of Labor
  Statistics projects **home health and personal care aides to add more new jobs
  than any other occupation this decade**, with **hundreds of thousands of
  openings every year** — the large majority just to *replace workers who leave*.
- It is **underpaid and unstable.** Median pay sits near **$16/hour** (BLS), and
  annual caregiver **turnover is commonly reported between roughly 40% and 65%**,
  higher at some agencies [VERIFY: PHI / Home Care Pulse benchmarking]. Agencies
  spend enormous effort recruiting and re-training instead of delivering care.
- The demand behind it is the same demand Track 1 addresses: an estimated
  **63 million** Americans are caring for an aging or ill loved one, and many of
  those families lean on paid workers to survive it.

Agencies **cannot hire their way out of this.** The math does not work: the labor
pool is finite, wages are constrained by thin reimbursement, and the population
needing care is climbing. The only durable levers are (1) **efficiency per
worker** — returning hours now lost to paperwork and coordination back to care —
and (2) **worker well-being and retention** — making the job less isolating and
less frustrating so people stay.

### Where the hours actually go

A direct-care worker's day is not one client; it is a **route of several short
visits** across different homes — the industry's own "rounds." Across that day,
a large share of the worker's time is **not care**. It is:

- **Documentation.** Every visit must be written up — what happened, how the
  person was, what was done. This is the single heaviest, most-hated recurring
  task, and it is usually done from memory at the end of a shift.
- **Coordination and communication.** Knowing which client is next, what changed
  since the last visit, and when to pull in a nurse or supervisor.
- **Watching for early warning signs** — a person declining, falling more, or
  running out of a medication — with no tooling to surface it, so problems become
  crises before anyone notices.

Reducing that administrative and cognitive load — *without* adding another
compliance chore — is the highest-leverage thing software can do for this
workforce. That is the entire design premise of Care Rounds.

## The solution: an AI care-operations app for the direct-care team

**Care Rounds is a mobile app (iOS + Android) for the paid direct-care team.**
Where our Track 1 product, Holdclose, serves the *family* caregiver of one loved
one, Care Rounds serves the *paid worker and their agency* across a **caseload of
many clients** — same product DNA and safety design, pointed at the workforce.

The AI does four things, each aimed squarely at the hours identified above. All
four are **built and working today**, not concepts:

**1. Ambient visit documentation — the flagship ("the note that writes itself").**
The worker taps *Document visit*, then simply **talks** (or types) a quick,
messy account of how the visit went. The AI turns it into a **structured,
reviewable visit note** — a summary, observations, the care tasks completed, and
anything to flag — with **zero typing**. Nothing is saved until the worker
reviews it. This attacks the day's heaviest task directly: the note writes
itself from a few spoken sentences. (ACL Track-2 use case #2, *Documentation*.)

**2. A client-grounded AI coach, with a path to a human.** For the specific
person in front of the worker, a **coach grounded in that client's real care
data** answers in-the-moment questions ("what changed since the last visit,"
"how do I help with this"), and a **code-side (non-LLM) watchdog escalates to a
supervisor** when something concerning appears — real-time coaching *with* a
built-in human hand-off. (Use cases #4 *Real-time coaching* and #7 *Data
aggregation*.)

**3. Explainable early-warning ("predictive care-need") flags.** Care Rounds
surfaces **rule-based, explainable risk signals** from the data the worker
already enters — a **repeated-falls trend** from visit notes, a **medication
running low or out of refills** from its own refill-runway estimate — on a
"Watch for" card, each stating the plain reason it fired. This catches rising
need early **without** a black-box model or new hardware. (Use case #5,
*Predictive analytics.*)

**4. AI-guided care-plan checklist.** Grounded in the client's profile and
medications, the AI **proposes a checklist of concrete visit tasks**; the worker
reviews, unchecks what doesn't fit, and approves the rest into the client's
routine. Human-in-the-loop, always. (Use cases #4 / #9.)

Organizing all of this is a **workforce-shaped information architecture**: a
**persistent client switcher** so the worker always knows — and can one-tap
change — which client the whole app is centered on; a **"Today's visits"** view
that leads the home screen with the worker's **route across every client** (one
in progress *now*, with a *Start visit* action, the rest ahead); a **My Rounds**
tab for the full cross-client day; a **Team** hub with the client roster,
caregivers, shifts, and assignments; and a **supervisor-flag inbox** where the
ambient note's escalations and the worker's own flags land for a human to
resolve.

### Scope discipline: what Care Rounds is *not*

A workforce app can drift into competing on feature checklists with the big
incumbent agency platforms (EVV, billing, scheduling optimization). We
**deliberately do not**, because that is commodity, non-AI, regulation-owned
territory that does nothing for the worker's day. Care Rounds is **not** an EVV
product (its lightweight check-in/out is framed as *time-saved*, never
compliance), **not** billing/claims/payroll, **not** a scheduling-optimization
engine, **not** an applicant-tracking/hiring system, and **not** remote hardware
monitoring. Every feature is measured against one test: *does it reduce a
worker's burden through AI, or just match an incumbent's checklist?* We build the
first and decline the second.

### A note on appointment scheduling — a clear role boundary

Consistent with how the industry actually works, **the frontline aide does not
schedule medical appointments** — that is a care-coordinator or family function;
the aide's role is to *know about* a visit, prep for it, arrange transport, and
take notes at it. Care Rounds therefore does **not** put appointment *management*
in the aide's hands. The natural home for appointment *creation* is the family
side — our Track 1 product, Holdclose — and a planned **cross-product connection**
would let a family-created appointment surface **read-only** to the assigned
worker in Care Rounds. Two products, one shared care circle, each matched to its
real-world role.

## End-user input and how it shaped the design

[FOUNDER: This is the User-Centered evidence — the criterion that scores near
zero without real, traceable input. Fill from your field feedback. For each
concrete example, state: (a) *who* (a direct-care worker or an agency
owner/administrator, by role — named only with consent), (b) *what they said*,
and (c) *what Care Rounds changed because of it.* A few specific "input → change"
links is all the criterion needs. Two examples already true of the build you can
frame here:

- A day of visits was originally modeled as thin/single-client; after grounding
  it against how aides actually work — **a route of multiple clients a day,
  often seeing a client twice (a morning and an evening call)** — the demo and
  the "Today's visits" design were rebuilt to that pattern.
- Appointment *management* was reconsidered and removed from the aide-facing app
  after confirming, against the industry norm, that **booking is a coordinator's
  job, not the aide's** — reframed to read-only awareness fed from the family
  side.

Replace/expand with your own documented sessions, and secure consent-to-cite for
anyone named. Recruit 1–3 more direct-care workers or an agency contact for a
short July session and document it here.]
