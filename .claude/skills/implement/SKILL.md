---
name: implement
description: "Implement ONE atomic task from a planned feature. Triggers on 'implement task N', 'build task N', 'do the next task', 'implement <specific task>', or /implement. One task per invocation, human-gated checkpoint at the end. Do NOT use for end-to-end feature work — that's /build. Do NOT use for planning — that's /plan."
user-invocable: true
---

# Implement

Implement one atomic task. One task per invocation. Stop at the end and ask before continuing.

**Input:** task identifier (number, title, or "the next one") and the feature it belongs to. If feature is unclear, infer from `docs/project_status.md` (the in-progress feature) or ask.

---

## Step 1: Load just enough context

1. Read `docs/Features/<feature-name>.md` — find the task and its description.
2. Read **only** the files the task touches and any files those import from. Don't pre-read the whole feature.
3. Skim `docs/architecture.md` only if the task touches a new layer or pattern.
4. Skim the relevant `docs/standards/*` only if the task is in that domain (e.g., touch `errors.md` when adding a new error path).

Do not load the full codebase. Do not load other features' docs.

---

## Step 2: Implement

- Follow patterns in surrounding code — match style.
- **Search before you write** — if a utility/helper might already exist, grep for it. Reuse over rebuild (AGENTS.md §10.2).
- Keep the change minimal and focused on this task only. No drive-by refactors.
- No tests in this step — those land in `/test` for the whole feature.
- No documentation updates here — those land in `/ship`.

---

## Step 3: Verify locally

Run the project's lint and type-check on the changed files. Fix anything you broke. Don't run the full test suite — that's `/test`.

If lint/type-check has no clean per-file mode, run the cheapest scope that covers the change.

---

## Step 4: Checkpoint

End with an **explicit confirmation** like:

> Task <N> complete: <one-line summary>.
> Files changed: `path/a.ts`, `path/b.tsx`.
> Lint/type-check: pass.
> Ready for the next task, or do you want to `/test` first?

Update the task's checkbox in `docs/Features/<feature-name>.md` to `[x]`. Do not touch any other doc.

---

## Constraints

- **One task per invocation.** Do not chain into the next task without explicit user go-ahead.
- **No docs.** Don't update `changelog.md`, `project_status.md`, `decision_log.md`, or `architecture.md` here — `/ship` handles those.
- **No commits.** Don't `git add` or `git commit`. The user decides when to commit.
- **No tests written here.** Implementation only. Tests are a single `/test` pass after the feature is done.
- If the task is blocked (missing dep, ambiguous spec, broken upstream), stop and surface the blocker — don't paper over it.
