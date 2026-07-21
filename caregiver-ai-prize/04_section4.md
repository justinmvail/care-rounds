# Section 4 — Alignment with the Caregiver AI Principles

> Maps 1:1 to ACL's seven official principles (exact order + wording). Each → a
> concrete, built Care Rounds feature, not an aspiration. `[FOUNDER: …]` = verify.

Care Rounds was designed around ACL's seven Caregiver AI Principles. Each is met
by a real, working feature:

**1. Protect privacy, dignity, and choice.** Client care data is **per-client and
portable** — the worker's device holds the record, and the shared care-circle
layer is gated so **assignments govern who can see which client**. All network
traffic is encrypted **in transit (TLS)**; the on-device database sits on the
phone's **OS device encryption**, with OS cloud backups disabled so the record is
not swept into iCloud or Google Drive. Server-synced team data resides on
**Cloudflare D1 and R2**. Critically, **the AI runs on Cloudflare Workers AI** —
an open-weight model on our own cloud — so the client data used to ground the
coach **never goes to a separate AI vendor**. We do not sell care data. Dignity is
built into the language: the person receiving care is **"your client,"** and the
worker is a professional whose time and judgment the product respects.

**2. Support human-in-the-loop accountability.** Care Rounds **augments, never
replaces, the worker's judgment.** The ambient visit note is **reviewed and
edited before it saves**; the AI-suggested care-plan checklist is **approved
task-by-task**; every AI action that changes care data — in chat *or* voice —
routes through an explicit **confirmation**; and the coach's guidance is
**grounded in the client's own data** so the worker sees the reasoning. When the
data is thin or the model is unsure, it **flags that and escalates to a
supervisor** rather than asserting. The **supervisor-flag inbox** is the human
hand-off made explicit — a flag is a task *for a person* and stays open until a
human resolves it, never auto-closed.

**3. Support caregivers' well-being and reduce burden.** This is Care Rounds'
entire purpose — **return caregiving time to a strained, high-turnover
workforce.** Ambient documentation turns the day's heaviest task from minutes of
end-of-shift typing into a few spoken sentences; the client-grounded coach cuts
the "I don't know what to do / who to call" stress of the hard moments;
early-warning flags reduce the crises that make the job frightening; and the
rounds view removes the friction of tracking a multi-client day. Less paperwork,
less scheduling chaos, guidance in the moment — directly aimed at burnout and
retention.

**4. Supplement, not replace, human connection.** By automating the **admin and
the watching**, Care Rounds gives the worker **more** time *with* the client, not
less — the automation targets the paperwork, never the caregiving. The **Team**
layer and the supervisor channel connect an otherwise-isolated frontline worker
to their supervisor and teammates. The AI is a tool; the humans do the caring,
and the escalation path deliberately routes concerns **to people**.

**5. Allow personalized and flexible care.** Guidance and suggestions are
**grounded in the specific client's situation** (their conditions, medications,
recent visit notes), and the app fits **each worker's actual caseload and route**
— a persistent client switcher and a per-client view mean the whole app
re-centers on whoever the worker is with. It is not a single-diagnosis or
one-size template; it adapts per client and per worker.

**6. Promote safety, reliability, and transparency.** The coach is **transparent**
(educational, not diagnostic; grounded and reason-showing; uncertainty flagged)
and its guardrails are **structural and model-independent**: a code-side (non-LLM)
**crisis watchdog**, human-in-the-loop confirmation on every care-data change, and
a **model-agnostic** architecture that lets us swap a model that underperforms for
any group. The predictive early-warning flags are **explainable rule-based
signals**, each stating the plain reason it fired — deliberately **not** a
black-box risk score. Care Rounds shares Holdclose's **Data Output Logs** (41
cycles, 41/41 guardrails held — dose-change, diagnosis, prompt-injection, and
unknown-protocol probes all correctly refused, crisis referral fires independent
of the model); those guardrails are identical here. [FOUNDER: optionally re-run
the harness against the Care Rounds coach for a Track-2-specific log.]

**7. Ensure affordability and access.** The workforce and the agencies that employ
it operate on **thin margins**, so affordability is not a nicety — it is the whole
adoption question. Care Rounds runs on the **phone the worker already carries**
(no new hardware), and the **open-weight, self-hosted model keeps inference cost
low** enough to price for thin-margin agencies. Its **local-first** design keeps
working with limited connectivity in the field, and every real inference call is
metered behind per-user quotas and a global spend cap so cost stays bounded.
[FOUNDER: state the intended pricing commitment — e.g. "priced per-agency at a
transparent, low per-seat rate; no cost to the individual worker."] This meets the
direct-care workforce where it is — the heart of ACL's home- and community-based
mission.
