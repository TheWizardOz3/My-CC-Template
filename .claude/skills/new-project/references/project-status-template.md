# Project Status Template (used by /new-project Phase 4)

Question bank + section mapping. Most fields are derivable from product_spec + architecture — only ask what isn't.

---

## Derivable fields (don't re-ask)

| Field in `docs/project_status.md` | Source |
|---|---|
| `{{PROJECT_NAME}}` | Product spec §1 |
| Current milestone scope (in-scope) | Product spec MVP feature list |
| Out-of-scope items | Product spec non-goals |
| Tech stack reference | Architecture doc |
| Feature priorities | Product spec ordering (or ask if unclear) |

---

## Ask the user

1. **Starting state?** (multiple-choice)
   - **Zero** — fresh repo, nothing built yet
   - **Partial scaffold** — boilerplate or auth in place
   - **Migrating** — existing codebase being adapted

2. **Known blockers or risks?** (free-form, can be empty)
   Capture anything that could derail Day 1 — missing API key, undecided design call, blocked dependency.

3. **Timeline expectations?** (multiple-choice + free-form)
   - No fixed deadline
   - Soft target: <date>
   - Hard deadline: <date>

4. **Priority adjustments to product_spec MVP order?** (free-form, optional)

---

## Compose the status doc

Sections (per `docs/project_status.md` template):

| Section | Content |
|---|---|
| **Current Milestone** | "MVP" (default name); reference product_spec §5 |
| **In Scope for This Milestone** | Bullet list of MVP features |
| **Explicitly Out of Scope** | Table from product_spec non-goals |
| **Boundaries** | One-line restatements of the top 3 non-goals |
| **Completed** | Empty unless starting state = "Partial scaffold" or "Migrating" |
| **Not Started** | MVP features in priority order, with priority (P0/P1/P2), dependencies (or "None"), complexity (LOW/MED/HIGH) |
| **Upcoming Work — Next Up** | First 3 features from "Not Started" |
| **Known Issues** | From blockers/risks question, or empty placeholder |
| **Tech Debt** | Empty placeholder ("None at MVP start.") |

---

## Writing rules

- **Be terse.** This doc gets re-read every session. Long descriptions = wasted context.
- One line per feature in the Not Started list. Detail lives in `docs/Features/<feature>.md` once `/plan` runs for that feature.
- Don't fabricate complexity estimates — when unsure, write `MED` or `TBD`.
- Stamp `**Last Updated**: YYYY-MM-DD` (today's date).
- Confirm before saving.
