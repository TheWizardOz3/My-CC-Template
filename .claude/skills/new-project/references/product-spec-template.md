# Product Spec Template (used by /new-project Phase 1)

Question bank + section structure. The skill asks each question via `AskUserQuestion`, then writes the filled-in spec to `docs/product_spec.md`.

The actual `docs/product_spec.md` ships with placeholder `{{PLACEHOLDERS}}` already in place. This file lists what to ask and which placeholder gets each answer.

---

## Sections to fill (in order)

### §1.1 Product Vision Statement
**Ask:** "In one sentence, what does this product do, and what does success look like?"
**Replaces:** the `{{A single sentence...}}` block under §1.1.

### §1.2 Problem Statement
**Ask:** "What problem does this solve? Why now?"
**Replaces:** the `{{What problem...}}` block under §1.2.

### §1.3 Target Audience / User Personas
**Ask:** "Describe your primary user(s). Role, technical level, what they're trying to do, what frustrates them today."
**Replaces:** the `{{PERSONA_1_NAME}}` row(s) in the personas table. Add 1–3 rows.

### §1.4 Key Value Proposition
**Ask:** "Why would a user choose this over what they use today?"
**Replaces:** the `{{What unique value...}}` block under §1.4.

### §2 UX Guidelines
**Ask:** "Three design principles that should guide all UX decisions" (free-form, 3 short phrases).
**Replaces:** `{{PRINCIPLE_1}}` … `{{PRINCIPLE_3}}` blocks.

Visual design system (colors, typography, spacing) — leave as `{{PLACEHOLDER}}` if not yet decided. Note in the doc: "Filled in during design phase, not at onboarding."

### §5 MVP Scope (most important)
**Ask sequentially:**
1. "List the features in MVP" (free-form, bulleted).
2. "Anything explicitly out of scope for MVP that you want to revisit later?" (free-form).
3. "What metric tells you MVP is working?" (free-form).
4. "Any hard constraints — timeline, budget, regulatory, team size?" (multiple-choice with free-form fallback).

These answers populate the milestone definitions, in-scope/out-of-scope sections, and the success-metrics block.

---

## What to skip / leave for later

- Detailed acceptance criteria per feature — those land in `/plan` per feature, not here.
- Visual design system details (color tokens, typography scale) — fill in when design starts.
- Per-feature specs — `docs/Features/<feature>.md` is created by `/plan`, not `/new-project`.

---

## Writing rules

- Replace `{{PLACEHOLDERS}}` with real content. Don't leave them in.
- Where the user didn't answer, write `{{TODO: <what's missing>}}` so it's visible.
- Don't pad. A 2-line vision statement beats a 5-paragraph one.
- Confirm with the user before saving.
