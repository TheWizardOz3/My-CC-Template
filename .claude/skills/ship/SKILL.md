---
name: ship
description: "Finalize a completed feature: lint, type-check, simplify pass, security review, doc updates, conventional commit. Triggers on 'ship X', 'finalize X', 'wrap up the X feature', or /ship. Runs after /test is green. Do NOT use to end a session — that's /end-session. Do NOT use mid-implementation."
user-invocable: true
---

# Ship

Per-feature finalize. Lint, simplify, security review, docs, commit. Delegates the heavy lifting to built-in skills and the `doc-updater` agent — `/ship` is the orchestrator.

**Input:** feature name. Infer from `docs/project_status.md` (in-progress feature) if not given.

---

## Step 1: Lint and type-check

Run the project's lint and type-check at full scope. Fix any errors before continuing — don't ship red.

If a lint rule fights the implementation, **fix the code, not the rule**. Don't disable rules without an explicit reason recorded in `decision_log.md`.

---

## Step 2: Simplify pass (delegate)

Invoke the built-in `/simplify` skill on the changes for this feature. It reviews for reuse, quality, and efficiency, then fixes any issues found.

If `/simplify` reports nothing actionable, continue. If it makes changes, re-run lint/type-check.

---

## Step 3: Security review (delegate)

Invoke the built-in `/security-review` skill. It scans pending changes for OWASP-style issues (injection, secrets, auth, input validation).

Resolve any high or medium findings before commit. Low findings: judgment call — note them in `decision_log.md` if shipped as-is.

---

## Step 4: Update docs (delegate to `doc-updater`)

Spawn the `doc-updater` agent with:
- The git diff for this feature (`git diff main...HEAD` or staged diff, whichever is in scope)
- The feature doc path (`docs/Features/<feature-name>.md`)
- A one-line summary of what shipped

The agent applies brevity-enforced updates to:
- `docs/changelog.md` — 1–2 lines, "Added/Changed/Fixed X"
- `docs/project_status.md` — move feature from In Progress to Completed; trim sequencing detail
- `docs/decision_log.md` — only if a non-obvious tradeoff was made (with `AI Instructions` block per AGENTS.md §11.2)
- `docs/marketing-strategy.md` — only when the diff touches `marketing/` or `apps/marketing/`; same rules as `project_status.md`

The agent will **not** touch `docs/architecture.md`, feature docs, or `.agents/product-marketing-context.md` — that's your job here. If tech stack, schema, or API surface changed, update `docs/architecture.md` directly. If marketing positioning shifted, re-run `/marketing-context`. Also update the feature doc itself: fill in any sections left as `{{TODO}}`, mark all tasks `[x]`, capture any post-hoc notes.

---

## Step 5: Conventional commit

Stage **only the files you intend to ship** — never `git add .` or `-A` (this is enforced by the safety-guard hook).

Write a Conventional Commit per AGENTS.md §4.1:

```
feat(scope): one-line subject under 72 chars

Optional body explaining why, not what.

Refs: #<ticket>
```

Present the commit message for user approval before running `git commit`. Do not push — pushing is a separate, explicit user action.

---

## Step 6: Confirm

End with:

> Shipped <feature-name>.
> - Commit: `<hash>` `<subject>`
> - Docs updated: changelog, project_status<, decision_log, architecture if applicable>
> - Next: `/ship` another feature, `/plan` new work, or `/end-session` to wrap.

---

## Constraints

- **Never `git add .` or `-A`** — staged files only, by name. (Hook will block this anyway.)
- **Never `git push`** without explicit user instruction.
- **Don't squash unrelated changes** into this commit. If `git status` shows files outside this feature's scope, surface them and ask before staging.
- **Don't skip the simplify or security-review delegations** — they're cheap and catch real issues.
- If any phase fails (lint red, security finding, simplify churn), stop and surface the failure. Don't ship around problems.
