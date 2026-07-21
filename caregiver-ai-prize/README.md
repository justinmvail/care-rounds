# Care Rounds — ACL Caregiver AI Prize, Phase 1 (Track 2)

**Track 2 — AI Tools for Extending the Caregiver Workforce.** This directory is
the Care Rounds submission packet. Deadline: **July 31, 2026, 5:00 pm ET**; one
email per application to **CaregiverAI@acl.hhs.gov**.

## The application (assemble in this order)
The narrative uses the ACL application outline's **exact section headings**:

1. `00_cover_abstract.md` — Cover page (≤1 pg) + Abstract (≤250 words).
2. `01_section1.md` — **Understanding of Need and Solution Design**.
3. `02_section2.md` — **Implementation Approach**.
4. `03_section3.md` — **Usability and Integration**.
5. `04_section4.md` — **Alignment with Caregiver AI Principles** (7, 1:1).
6. `05_section5.md` — **Meritorious Prize Eligibility (Optional)** — keep or drop.

Appendix (≤10 pp): letters of support / commitment (see `outreach_email.md`) +
optional supporting docs, including the Data Output Logs.

## What Care Rounds is (one paragraph)
An AI care-operations app for the **paid direct-care team** (aides, agencies).
Flagship: **ambient visit documentation** — the aide talks, the AI writes the
structured note. Plus a **client-grounded coach** with a **supervisor escalation
channel**, **explainable early-warning flags** (falls trend, refill runway), and
an **AI-guided care-plan checklist** — organized around a real multi-client day
of rounds. Same architecture + responsible-AI design as our Track 1 product,
Holdclose, re-pointed from the family to the workforce.

## Status
- **Product:** built + tested (Flutter iOS/Android, ~1,900+ tests green,
  Cloudflare Worker backend, open-weight model on Cloudflare Workers AI). TRL-3+.
- **Packet:** `00`–`05` + `outreach_email.md` + `SUBMISSION_TODO.md` are rewritten
  for **Track 2**. The remaining reference docs in this dir (`NARRATIVE.md`,
  `DATA_OUTPUT_LOGS.*`, `GAP_ANALYSIS.md`, `DEEP_DIVE_AUDIT.md`, `REQUIREMENTS.md`,
  `CONTEST_MASTER_REFERENCE.md`, `recruiting_kit.md`, `acl_clarification_email.md`)
  were **copied from the Track-1 (Holdclose) packet at fork time** and still read
  Holdclose — treat them as reference, not final Track-2 content.
- **Design source of truth:** `../docs/PRODUCT_DESIGN.md` (§1 thesis, §2 the nine
  ACL use cases, §2a strategy + anti-goals, §6 six criteria, §7 seven principles,
  §10 implementation status).

## What's left → `SUBMISSION_TODO.md`
The narrative is drafted; what remains is founder-only: **user-centered evidence
+ partner letters** (the two people-dependent criteria), cover attestations/bio,
pricing + pilot specifics, the §5 keep/drop call, `[VERIFY]` on the workforce
stats, and the final 508-compliant PDF. See `SUBMISSION_TODO.md`.
