# Section 3 — Usability and Integration

> Error-prevention by design, transparency, empowerment, realistic-conditions
> testing, integration into the workday, and interoperability. `[FOUNDER: …]` =
> founder input required.

## Designed for the real conditions of the job

A direct-care worker uses a phone **one-handed, between tasks, in someone's home,
often at the end of a long shift.** Care Rounds is built for exactly that:

- **Voice-first where it matters most.** The single heaviest task — the visit
  note — is done by **talking**, not typing. A center microphone is present on
  every screen for hands-free capture. This is the difference between a note that
  gets written and one that gets skipped.
- **A caseload you never lose track of.** A **persistent client bar** at the top
  of every screen names the client the app is centered on and switches with one
  tap — so "whose 8am medications are these?" is never ambiguous, which is a
  *safety* property, not just convenience.
- **The day leads with what's next.** Home opens on **today's visits** across
  clients, with the current visit highlighted and a one-tap **Start visit** that
  re-centers the app on that client. The tool matches the shape of the workday
  (a route), so it fits the work instead of fighting it.
- **Large targets, calm layout, plain language.** Generous hit areas, a warm
  high-contrast palette, and sections grouped by what the worker is doing
  ("This visit," "Client info," "Team & training").

## Error prevention *by design*, not by warnings

Per the ACL emphasis on preventing mistakes through design rather than
after-the-fact warnings:

- **Nothing changes care data without a deliberate confirmation.** The ambient
  visit note is **reviewed and edited before it saves**; the AI-suggested
  care-plan tasks are **approved one at a time**; destructive actions require an
  explicit in-thread confirm. There is no silent write.
- **The AI proposes; the worker disposes.** Scan-to-import and the visit note
  **pre-fill** and the worker **approves** — the human is always the last step.
- **Weak data is flagged, not guessed.** When the model is unsure or the input is
  thin, it surfaces that rather than inventing detail.

## Transparency and empowerment, not replacement

- **The coach shows its work** — its guidance is grounded in, and refers to, the
  client's own data, so the worker can see *why* it says what it says.
- **It augments the worker's judgment; it never replaces the human.** The AI
  automates the *paperwork and the watching* so the worker spends **more** time
  in care and human contact, not less — and the **supervisor-flag channel keeps a
  human in the loop** for anything that matters. The vendor/model is never named
  in the interface; the *capability* is presented plainly, the *judgment* stays
  with the worker.
- **The escalation path is a human hand-off by design** — a flag is a task *for a
  person*, never an automated decision about someone's care.

## Realistic-conditions testing

Care Rounds is exercised the way it will be used: an automated suite of
**~1,900+ tests** including **integration flows** (a full multi-screen path
through the shell), **visual "golden" tests on every screen**, and deterministic
fakes for the AI so behavior is validated without a live model in the loop. A
**rich, realistic demo dataset** — a full caseload of multiple clients, a signed-in
worker, a day of cross-client visits, per-client medications with real refill
runways, and open supervisor flags — lets the whole product be driven against
lifelike volume. [FOUNDER: Phase-2 adds **testing with real direct-care workers**
in real homes, the strongest form of realistic-conditions validation — secure
this through the agency pilot partnership.]

## Integration into the agency day, and interoperability

- **It fits the existing workflow, not a parallel one.** Care Rounds slots into
  the aide's actual day (rounds → visit → note → flag) rather than adding a
  separate compliance chore. Deliberately **out of scope** are the incumbent
  systems (EVV, billing, scheduling optimization) — we integrate *around* them
  rather than trying to replace them.
- **Two products, one care circle.** Care Rounds and Holdclose share a care-data
  spine, which is the basis for a planned **cross-product connection** so that,
  e.g., a **family-scheduled appointment (Holdclose) surfaces read-only to the
  assigned worker (Care Rounds)** — the interoperability that matches each role.
- **Portable, standard-friendly outputs.** The care record is exportable, and a
  shareable **care-summary handoff** (a one-page picture for the next caregiver,
  the supervisor, or a clinician) already exists — the seed of EHR/agency-system
  interoperability, which is a Phase-2 roadmap item rather than an overclaim
  today.

## Accessibility

Care Rounds inherits Holdclose's accessibility posture: OS **Dynamic Type**
support with an in-app text-size control, simple linear flows, a warm
high-contrast palette, and semantic labeling for screen readers on interactive
controls, with **WCAG-AA hardening in progress**. The audience — a workforce that
is time-pressed, often multilingual, and running on little sleep — makes calm,
low-friction, low-reading-load design a core requirement, not a polish item.
