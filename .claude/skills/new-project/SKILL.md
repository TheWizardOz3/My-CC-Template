---
name: new-project
description: "Bootstrap a fresh project from this template: interactive walk-through that fills in product_spec, architecture, env, project_status, and design-references via AskUserQuestion. Triggers on 'new project', 'set up this project', 'onboard', '/new-project', or running on a fresh clone with template placeholders still in docs/. Run ONCE per project. Do NOT use for existing projects with filled-in docs."
user-invocable: true
---

# New Project (interactive onboarding)

Walk a fresh clone of this template through five short interactive phases. Each phase asks targeted questions, then writes one doc. Templates live in `references/`.

**Run once per project.** If `docs/product_spec.md` no longer has `{{PLACEHOLDER}}` strings, the project is already onboarded — confirm with the user before continuing.

**Asking is better than guessing.** Use the `AskUserQuestion` tool for each prompt — present 2–4 specific options when there's a clear preference axis (tech stack, hosting, scale), and use free-form when the answer is genuinely open (project name, vision).

---

## Phase 0: Pre-flight

1. Check whether `docs/(ignore) brainstorm.md` exists and has content. If yes, read it — it's the user's raw seed material and replaces several questions below.
2. Confirm scope with the user: "Run full onboarding (5 phases, ~10–15 min) or just the part you want?" Default is full.
3. List the 5 phases:
   1. Product spec
   2. Architecture
   3. Environment
   4. Project status
   5. Design references

---

## Phase 1: Product spec

**Goal:** Fill `docs/product_spec.md` from `references/product-spec-template.md`.

Read `docs/product_spec.md` (currently a template with placeholders). Read `references/product-spec-template.md` for the question bank.

Ask sequentially via `AskUserQuestion` (one question at a time, not a wall of forms):

1. **Project name** (free-form)
2. **One-line vision** (free-form)
3. **Problem being solved** (free-form)
4. **Target user persona(s)** (free-form, can list 1–3)
5. **MVP scope** — which features are in MVP vs. later? (free-form list, or build iteratively)
6. **Success metrics** — how will you measure this works? (free-form)
7. **Hard constraints** — timeline, budget, regulatory, team-size? (multiple-choice + free-form)
8. **Explicit non-goals** — what is this NOT? (free-form)

Write the filled-in spec to `docs/product_spec.md`. Confirm before moving on.

---

## Phase 2: Architecture

**Goal:** Fill `docs/architecture.md` from `references/architecture-template.md`.

Read `docs/architecture.md` and `docs/product_spec.md` (just-written). Use product_spec to inform sensible defaults — don't re-ask things already implied (e.g., if MVP is a CLI tool, don't ask about frontend frameworks).

Ask:

1. **Frontend framework** (multiple-choice: React/Next.js/Vue/Svelte/None/Other) — skip if no UI
2. **Backend framework** (multiple-choice: Node/Python/Go/Rust/Other/None for static-only)
3. **Database** (multiple-choice: Postgres/SQLite/MongoDB/None/Other)
4. **Hosting / deploy target** (multiple-choice: Vercel/Cloudflare/AWS/Fly/Local-only/Other)
5. **Auth approach** (multiple-choice: third-party (Clerk/Auth0/Supabase)/roll-your-own/None)
6. **Scale expectations** — order of magnitude users / requests-per-day at MVP (multiple-choice: <100, 100–10K, 10K+, internal-only)
7. **Integrations** — third-party services to wire in? (free-form list)
8. **Security/compliance constraints** — PII, payments, HIPAA, SOC2? (multiple-choice + free-form)

Write the filled-in architecture to `docs/architecture.md`. Then update the **project-specific placeholders in `AGENTS.md`** (§1 Project Identity, §12 Quick Reference Commands) — do NOT touch §3–§11 universal sections. Confirm.

---

## Phase 3: Environment

**Goal:** Generate `.env.example` (and optionally `.env.local`) and document setup. Read `references/env-template.md`.

From the architecture answers, derive the env vars needed (e.g., `DATABASE_URL` if Postgres, `STRIPE_SECRET_KEY` if Stripe was named, etc.).

Ask:

1. **Existing accounts** — which services in the integration list do you already have credentials for? (free-form)
2. **Local dev port preferences** (free-form, default 3000/8000/etc.)
3. **Environment tiers** (multiple-choice: dev-only, dev+prod, dev+staging+prod)

Write `.env.example` with placeholder values and one-line comments. Do NOT write secrets to `.env.local` — leave that to the user, but confirm what they need to fill in.

If a `README.md` exists, update its setup section. Otherwise note "README setup section pending — write in Phase 9 of restructure."

Confirm.

---

## Phase 4: Project status

**Goal:** Fill `docs/project_status.md` from `references/project-status-template.md`.

Read the just-written product spec and architecture. Most fields are derivable; only ask what isn't.

Ask:

1. **Current state** — is anything already built, or starting from zero? (multiple-choice: zero / partial scaffold / migrating from existing)
2. **Known blockers or risks** at the start (free-form)
3. **Timeline expectations** for MVP (free-form, or "no fixed timeline")

Compose the status doc:
- Current milestone = MVP (default name)
- In-scope features = product_spec MVP list
- Out-of-scope = product_spec non-goals
- Not Started list = MVP features in priority order
- Known Issues + Tech Debt sections — empty placeholders are fine

Write to `docs/project_status.md`. Confirm.

---

## Phase 5: Design references

**Goal:** Capture example apps/sites whose UX/design the user admires. Saved to `docs/design-references.md` for `/ux-review` to use later.

Ask:

1. **Reference apps or sites** — name 2–5 products whose design quality you'd like to match (free-form)
2. For each, **what specifically you like** — e.g., "Linear's keyboard navigation", "Stripe Dashboard's typography hierarchy", "Things 3's empty states" (free-form, one per app)
3. **Anti-references** (optional) — products whose design you specifically want to avoid (free-form)

Write `docs/design-references.md`:

```markdown
# Design References

> Captured during /new-project. Used by /ux-review as the consistency benchmark.
> Update freely as taste evolves.

## References
- **<App 1>** (<URL if relevant>) — what you like: <one-liner>
- **<App 2>** ...

## Anti-references
- **<App>** — what you want to avoid: <one-liner>

## Notes
<Any cross-cutting design preferences not tied to a specific app>
```

Confirm.

---

## Phase 6: Wrap

Summarize what was written:

> Onboarded `<project-name>`.
> Files written: `docs/product_spec.md`, `docs/architecture.md`, `docs/project_status.md`, `docs/design-references.md`, `.env.example`, plus AGENTS.md §1 + §12 placeholders.
> Next: `/plan` your first feature, or read `docs/project_status.md` to confirm priorities.

Suggest the user delete `docs/(ignore) brainstorm.md` if it was used (or keep it — they may add to it).

---

## Constraints

- **Ask, don't guess.** AskUserQuestion every step. Defaults are fine; assumed answers are not.
- **One question at a time.** Don't dump a wall of fields.
- **Skip what's irrelevant.** No frontend = skip frontend questions. No DB = skip DB questions.
- **Don't fill sections you didn't ask about.** Leave `{{TODO}}` placeholders rather than fabricating content.
- **Don't run the full template suite on existing projects.** Detect filled-in docs at Phase 0 and offer partial mode.
- **Don't touch AGENTS.md universal sections (§3–§11).** Only update §1 Project Identity and §12 Quick Reference Commands.
- **Don't commit on the user's behalf.** End with a summary; let the user decide when/what to commit.
