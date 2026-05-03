---
name: marketing-context
description: "Bridge the dev-side product docs to a marketing-positioning context file that every marketing skill reads. Pre-populates from `docs/product_spec.md`, `docs/architecture.md`, `README.md`, and sample components in `src/`, then asks only for the marketing-specific gaps (personas, voice, customer language, competition, proof, pricing positioning). Writes `.agents/product-marketing-context.md`. Triggers on 'marketing context', 'set up marketing context', 'positioning', 'who is my audience', '/marketing-context', or running any marketing skill while `.agents/product-marketing-context.md` is missing. Project-side wrapper around the upstream `marketing-skills:product-marketing-context` skill — produces the same file shape so downstream marketing skills work unchanged."
user-invocable: true
---

# Marketing Context (bridge)

Single source of truth for product positioning, audience, voice, and competitive landscape. Output: `.agents/product-marketing-context.md` (cross-agent location — readable by Cursor/Codex too). Every marketing skill in the upstream plugin reads this file before doing anything else.

This skill is **the bridge** between the dev side (`docs/product_spec.md`, `docs/architecture.md`, `src/`) and the marketing side. It exists because the dev docs already capture half the answers — re-asking them wastes the user's time. It only asks for the marketing-specific gaps the dev side never captured.

The output schema mirrors the upstream `marketing-skills:product-marketing-context` skill exactly, so downstream marketing skills (`page-cro`, `copywriting`, `ad-creative`, etc.) work without modification.

---

## Auto-loaded context

Current product spec: !`cat "docs/product_spec.md" 2>/dev/null || echo "(missing — run /new-project first)"`

Current architecture: !`cat "docs/architecture.md" 2>/dev/null || echo "(missing — run /new-project first)"`

Current marketing context: !`cat ".agents/product-marketing-context.md" 2>/dev/null || echo "(none yet — first run, will create)"`

Top-level README: !`cat "README.md" 2>/dev/null | head -120 || echo "(no README)"`

Recent UI component names (best-effort): !`find src -maxdepth 4 -type f \( -name "*.tsx" -o -name "*.jsx" -o -name "*.vue" -o -name "*.svelte" \) 2>/dev/null | head -20`

---

## Step 0: Detect mode

**First run** — `.agents/product-marketing-context.md` does not exist or is `.gitkeep`-only.
→ Pre-populate from dev docs, ask gap questions, write the file.

**Re-run / update** — `.agents/product-marketing-context.md` exists with content.
→ Diff mode: identify which sections in the existing file are still consistent with current `docs/product_spec.md` and `docs/architecture.md`, surface drift, propose section-level updates. Don't overwrite blindly.

If the user says "rebuild from scratch", treat it as first run regardless.

---

## Step 1: Pre-populate from dev docs

Before asking the user anything, draft as many sections as possible from what the auto-loaded context already gave you. Map fields like this:

| Target section | Pull from |
|---|---|
| Product Overview → one-liner, what it does, product type | `docs/product_spec.md` (vision, problem, MVP scope) |
| Product Overview → product category, business model | `docs/product_spec.md` if present, else flag as gap |
| Target Audience → primary use case, jobs to be done | `docs/product_spec.md` (user persona, problem) |
| Target Audience → target companies, decision-makers | `docs/product_spec.md` if present, else flag as gap |
| Tech-buyer signals (informs "for technical buyers" framing) | `docs/architecture.md` (stack, integrations) |
| Glossary candidates / product nouns | UI component names from `src/`, README features list |
| Goals → business goal, conversion action | `docs/product_spec.md` (success metrics) |

Skip sections you can't fill from dev docs — those become the gap-questions in Step 2.

---

## Step 2: Ask only for the gaps

The dev side never captures these. Ask them now via `AskUserQuestion`, **one question at a time** (not a wall of forms). Skip a question if the answer is obvious from existing context.

1. **Personas (B2B only)** — who buys, who uses, who pays? Skip if B2C.
2. **Direct competitors** — same solution, same problem (free-form list).
3. **How current solutions fall short** — for each main competitor, one-line on the gap your product fills.
4. **Verbatim customer language** — exact phrases customers use to describe the problem and your solution. (If they don't have any yet: leave a `{{TODO}}` placeholder and note that `marketing-skills:customer-research` can fill this in later.)
5. **Brand voice** — tone (professional / casual / playful / technical / etc.) + 3–5 personality adjectives.
6. **Words to use / words to avoid** — short list each.
7. **Proof points** — metrics, customer logos, or testimonial snippets you can cite. (`{{TODO}}` is fine for pre-launch.)
8. **Pricing positioning** — premium / mid-market / cheapest / free-with-paid-tier? (Skip the actual numbers — those live elsewhere.)
9. **Switching dynamics (JTBD four forces)** — one short answer each:
   - **Push:** what frustrates them about their current approach
   - **Pull:** what attracts them to you
   - **Habit:** what keeps them stuck where they are
   - **Anxiety:** what worries them about switching
10. **Anti-persona** — who is explicitly NOT a fit for this product?

Use `{{TODO}}` placeholders for anything the user can't answer yet — better to ship an honest gap than to fabricate.

---

## Step 3: Compose `.agents/product-marketing-context.md`

Write the file with the **exact** schema below. This matches the upstream `marketing-skills:product-marketing-context` schema so downstream marketing skills work without translation.

```markdown
# Product Marketing Context

*Last updated: <YYYY-MM-DD>*
*Generated by `/marketing-context` (project bridge skill) from `docs/product_spec.md`, `docs/architecture.md`, `README.md`, and user-supplied gaps.*

## Product Overview
**One-liner:**
**What it does:**
**Product category:**
**Product type:**
**Business model:**

## Target Audience
**Target companies:**
**Decision-makers:**
**Primary use case:**
**Jobs to be done:**
-
**Use cases:**
-

## Personas
| Persona | Cares about | Challenge | Value we promise |
|---------|-------------|-----------|------------------|
| | | | |

## Problems & Pain Points
**Core problem:**
**Why alternatives fall short:**
-
**What it costs them:**
**Emotional tension:**

## Competitive Landscape
**Direct:** [Competitor] — falls short because...
**Secondary:** [Approach] — falls short because...
**Indirect:** [Alternative] — falls short because...

## Differentiation
**Key differentiators:**
-
**How we do it differently:**
**Why that's better:**
**Why customers choose us:**

## Objections
| Objection | Response |
|-----------|----------|
| | |

**Anti-persona:**

## Switching Dynamics
**Push:**
**Pull:**
**Habit:**
**Anxiety:**

## Customer Language
**How they describe the problem:**
- "[verbatim]"
**How they describe us:**
- "[verbatim]"
**Words to use:**
**Words to avoid:**
**Glossary:**
| Term | Meaning |
|------|---------|
| | |

## Brand Voice
**Tone:**
**Style:**
**Personality:**

## Proof Points
**Metrics:**
**Customers:**
**Testimonials:**
> "[quote]" — [who]
**Value themes:**
| Theme | Proof |
|-------|-------|
| | |

## Goals
**Business goal:**
**Conversion action:**
**Current metrics:**

---

## Source links
- Product spec: [`../docs/product_spec.md`](../docs/product_spec.md)
- Architecture: [`../docs/architecture.md`](../docs/architecture.md)
- Marketing strategy: [`../docs/marketing-strategy.md`](../docs/marketing-strategy.md)
- Re-run: `/marketing-context` (idempotent — diffs against current dev docs)
```

Ship `{{TODO}}` placeholders rather than empty fields where the user couldn't answer. Downstream skills can detect and surface them.

---

## Step 4: Re-run / diff mode

If `.agents/product-marketing-context.md` already exists:

1. Read it.
2. For each section that draws from `docs/product_spec.md` or `docs/architecture.md`, compare current dev-doc content to what's in the marketing context.
3. List sections that look stale (dev docs evolved, marketing context didn't follow).
4. Present a section-by-section update proposal. The user can accept all, accept some, or skip.
5. Apply only the accepted updates. Do not rewrite sections that are still accurate. Do not erase user-supplied marketing-only fields (personas, voice, competition, proof, etc.) unless the user explicitly says so.
6. Bump the `*Last updated:*` line.

---

## Step 5: Confirm and hand off

After writing:

1. Summarize which sections are filled, which are `{{TODO}}`, and what changed (if re-run).
2. Tell the user:
   > Marketing context written to [`.agents/product-marketing-context.md`](.agents/product-marketing-context.md). Every marketing skill (e.g., `marketing-skills:page-cro`, `marketing-skills:copywriting`) will read it automatically. Re-run `/marketing-context` whenever the product or positioning shifts — it's idempotent.
3. If the marketing-skills plugin isn't installed yet, mention: `/plugin marketplace add coreyhaines31/marketingskills` then `/plugin install marketing-skills@marketingskills`. Plugin skills become available after a session restart (per Phase M1 findings).

---

## Constraints

- **Don't re-ask what dev docs already answered.** Pull from `docs/product_spec.md` and `docs/architecture.md` first; only ask for the gaps.
- **Don't fabricate.** `{{TODO}}` is correct when the user can't answer.
- **Don't drift from upstream schema.** The section headings and field names must match `marketing-skills:product-marketing-context` exactly so downstream skills find what they expect. If the upstream schema changes in a future plugin version, update this skill in lockstep.
- **Don't write anywhere except `.agents/product-marketing-context.md`.** No spillover into `docs/marketing-strategy.md` or `marketing/` — those are for produced artifacts and rolling notes, not positioning.
- **Don't overwrite blindly on re-run.** Diff first, propose section-level updates, preserve user-supplied marketing-only content unless explicitly told to rebuild.
- **Cross-agent location is non-negotiable.** Always write to `.agents/product-marketing-context.md`, not `.claude/` or `docs/`. Other tools (Cursor, Codex) read this path too.
- **Don't commit on the user's behalf.** Show the result; let the user decide when to commit.
