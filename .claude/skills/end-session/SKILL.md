---
name: end-session
description: "Wrap up a work session: ensure docs are current, capture any decisions made during the session, leave clean handoff state. Triggers on 'end session', 'wrap up', 'wrap things up', 'close out', or /end-session. Do NOT use mid-feature — that's /ship. Do NOT use for per-feature finalization."
user-invocable: true
---

# End Session

Session-scoped housekeeping. Different from `/ship` (which finalizes one feature) — `/end-session` makes sure the **whole session** lands cleanly: docs current, decisions captured, handoff explicit. No new files. Updates `docs/changelog.md`, `docs/project_status.md`, `docs/decision_log.md` only.

Run all phases inline. Present a consolidated handoff at the end.

---

## Phase 1: Doc currency check

Look at what changed this session:

```bash
git status
git diff --stat HEAD~1 2>/dev/null || git diff --stat
```

For every meaningful code change (not pure-`.md`, not test-only):
- Is `docs/changelog.md` updated? If not, add a 1–2 line entry.
- Is `docs/project_status.md` reflective of current state? Update In Progress / Completed lists.

If `/ship` already ran for these features this session, doc updates likely happened — verify, don't duplicate.

---

## Phase 2: Decision capture

Scan the conversation for **decisions**: tradeoffs taken, patterns chosen, paths rejected. Anything a future contributor (or future-you) would want the rationale for.

For each decision worth keeping:
- Add an entry to `docs/decision_log.md` with date (YYYY-MM-DD), context, decision, rationale, and an `AI Instructions` block per AGENTS.md §11.2.
- Skip purely tactical choices ("used `Array.map` instead of a for-loop") — only architectural or directional calls.

If no decisions were made: skip this phase. Note "No decisions to log" in the handoff.

---

## Phase 3: Loose-ends check

Quick scan for things that would surprise next session:

- Uncommitted changes? Either commit them (via `/ship` if they're a feature) or note them in the handoff.
- WIP feature not finished? Make sure `docs/project_status.md` says so explicitly, with the next concrete step.
- Failing tests left red? Surface in handoff — don't paper over.
- TODO/FIXME left in code without a ticket? Either ticket it or remove it.

---

## Phase 4: Handoff

End with one of two statuses, stated directly:

**Complete** — session goal resolved, no resumption needed:

> **Handoff: Complete** — <one-line of what shipped>. Open items in `docs/project_status.md`.

**Continues** — session goal has unfinished work:

> **Handoff: Continues**
> Resume prompt: `<exact prompt to paste into a fresh session — reference specific files, don't say "read the session report">`
> What's left: <bullet list>
> Blockers: <anything that must happen first, or "None">

---

## Constraints

- **No new files.** Use existing `changelog.md` / `decision_log.md` / `project_status.md`.
- **No session report file.** The handoff lives in conversation, not on disk.
- **Brevity over completeness.** A 2-line changelog entry is better than a 2-paragraph one.
- **Don't re-do `/ship` work.** If the session's features already shipped, the docs are already updated — verify, then move on.
- **Don't commit on behalf of `/ship`.** Per-feature commits belong to `/ship`. `/end-session` may commit a small doc-only cleanup if needed, but only with explicit user approval.
