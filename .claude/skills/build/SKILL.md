---
name: build
description: "End-to-end orchestrator for simple-to-medium tasks: plan → implement (per task) → test, each phase delegated to a fresh subagent so the main thread's context stays clean. Triggers on 'build the X feature', 'add X end-to-end', '/build', or when the user wants 'just do the thing' without manually chaining /plan, /implement, /test. Do NOT use for complex/risky work where every task should be human-reviewed (use /plan + /implement + /test manually). Do NOT use for one-off bug fixes (use /debug)."
user-invocable: true
---

# Build (orchestrator)

End-to-end feature build via subagent dispatch. Each phase runs in its own context. The main thread holds only the orchestration state — never the full source files.

**The point:** `/plan` + 3–5 invocations of `/implement` + `/test` in one conversation eats the context window. `/build` runs the same workflow, but each phase exits before the next begins, so no phase pollutes the next phase's context.

**Use when:** simple-to-medium feature; you don't need to inspect every implementation step.
**Don't use when:** complex/risky work; you want human review between every task; one-off bug fix (use `/debug`); session housekeeping (use `/end-session`).

---

## Step 0: Capture the request

Take the user's task description verbatim. If it's vague (e.g., "build it"), ask for one sentence of clarity before dispatching anything — context wasted on speculation is the most expensive kind.

Confirm scope with the user **once** before proceeding. From here on, the main thread is a coordinator, not an implementer.

---

## Step 1: Planning subagent

Dispatch a `general-purpose` subagent (it has the `Skill` tool — `feature-dev:code-architect` does not, so it can't invoke `/plan`).

**Prompt template:**

> Invoke the `/plan` skill in **feature mode** for: <task description>.
>
> Follow `/plan` exactly — it will write `docs/Features/<feature-name>.md` and add a one-line in-progress entry to `docs/project_status.md`. Do not deviate from the skill.
>
> When `/plan` finishes, return a structured summary (do NOT include source-file contents):
> - `feature_name`: the slug `/plan` chose
> - `feature_doc_path`: path to the file `/plan` wrote
> - `task_list`: the implementation tasks `/plan` produced (number, one-line description, files touched)
> - `risks`: open questions or risks `/plan` flagged
> - `out_of_scope`: explicit exclusions

The skill is the source of truth for plan structure; this prompt only owns the "return structured summary" override.

---

## Step 2: Human gate (plan approval)

Read the feature doc the planning agent wrote (`docs/Features/<feature-name>.md`) — that's the canonical plan. Present it to the user with the agent's risk/scope notes. Ask for one of:

- **Approve** → proceed to Step 3
- **Edit** → small edits: amend the feature doc inline. Larger edits: re-dispatch Step 1 with the new constraints in the prompt.
- **Cancel** → stop. Optionally remove the feature doc and the `project_status.md` line that `/plan` wrote.

**Plan approval is the only mandatory human gate.** Without it, `/build` becomes an unsupervised loop.

> The feature doc is the only file the main thread reads. Do not read any source files referenced by the plan — trust the agents.

---

## Step 3: Implementation subagents (sequential, one per task)

For each task in the approved plan, dispatch a fresh `general-purpose` subagent. Do them **sequentially**, not in parallel — later tasks may depend on earlier ones.

**Prompt template:**

> Invoke the `/implement` skill for task <N> of feature `<feature-name>` (see `docs/Features/<feature-name>.md`).
>
> Follow `/implement` exactly, with these orchestration overrides:
> - **Skip the closing human checkpoint.** Do not ask "Ready for the next task?". Return the structured summary below instead.
> - All other `/implement` constraints stand: one task only, no commits, no doc updates beyond the task checkbox, no tests.
>
> Return:
> - `summary`: one-line description of what changed
> - `files_changed`: list of paths
> - `lint_typecheck`: `pass` | `fail` (with details if fail)
> - `blockers`: anything that stopped you, or `none`
> - `assumptions`: any judgment calls you made

After each task:
1. The subagent's `/implement` invocation already ticked the task checkbox — don't re-tick.
2. If `blockers` is non-empty → stop. Surface to user. Ask: continue, retry with new info, or abort.
3. If `lint_typecheck` is `fail` → stop. Surface the failure. Don't dispatch the next task on top of red.

**Key invariant:** main thread does not read source files. Trust agent summaries.

---

## Step 4: Test subagent

Once all implementation tasks return clean, dispatch one `general-purpose` test subagent.

**Prompt template:**

> Invoke the `/test` skill for feature `<feature-name>` (see `docs/Features/<feature-name>.md`).
>
> Follow `/test` exactly, with these orchestration overrides:
> - **Skip the closing "Ready to `/ship`?" prompt.** Return the structured summary below instead.
> - All other `/test` constraints stand: no commits, no doc updates, cost guard on paid APIs.
>
> Return:
> - `existing_tests`: pass / fail counts
> - `new_tests_added`: count + paths
> - `coverage`: criteria covered / criteria total
> - `browser_check`: `pass` | `n/a` | `skipped` (with reason)
> - `regressions`: list, or `none`

If the test agent reports failures, regressions, or a triggered cost guard, surface them. Don't auto-proceed to ship.

---

## Step 5: Hand off to user

Present a consolidated report:

> Built `<feature-name>` end-to-end.
> - Plan: <N> tasks, all complete
> - Files changed: <count> across <list>
> - Tests: <new count> added, full suite green
> - Browser check: <status>
> Ready to `/ship` from a clean context.

**Do not run `/ship` automatically.** `/ship` involves git operations and human judgment on commits — it's a separate explicit step.

---

## Failure modes

| Failure | Action |
|---|---|
| Planning agent returns vague tasks (no `file`/`action`/`verify`) | Loop back to Step 1 with stricter prompt; don't proceed |
| User rejects plan | Stop. Don't lossy-loop trying to guess what they wanted. Ask. |
| Implementation agent blocked | Surface blocker. Ask user: continue, retry, abort. Don't dispatch next task. |
| Implementation agent makes unrelated changes | Treat as a failure. Stop, surface, ask. |
| Test agent reports regression | Stop. Surface. The feature is not done. |
| Cost guard triggered (paid API) | Stop. Ask user before any paid call. |

---

## Constraints (main thread)

- **Never read source files in the main thread.** The feature doc is the only file you read — that's the orchestration state. Trust agent summaries for everything else.
- **Skills own their phase logic.** `/build` only owns orchestration deltas: which agent runs which skill, the structured-return overrides, and the human gate. If `/plan`, `/implement`, or `/test` change their conventions, `/build` inherits the change for free.
- **Plan approval is the only auto-gate.** Other gates fire only on failure (blocker, lint fail, regression, cost guard).
- **Sequential implementation.** Do not parallelize tasks — order matters.
- **No commits, no pushes.** `/ship` handles those. Doc updates beyond what the underlying skills already do (feature doc creation, task checkboxes) are also `/ship`'s job.
- **No `/ship` chaining.** End at the handoff. The user runs `/ship` deliberately.
