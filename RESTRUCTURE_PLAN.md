# My-CC-Template Restructure Plan

> Working document for restructuring this template to follow Claude Code best practices, drawn from `jules` (operational patterns, hooks, skills) and `claude-code-best-practice` (architecture demos, hook config). Built for piece-by-piece execution across multiple sessions — each phase below is self-contained.

**Status:** Phases 1–9 complete; Phase 10 cleanup partial (vibe-coding-prompts removed; this plan kept for reference).
**Last updated:** 2026-04-25

---

## Reference repos (read these for comparison)

When executing any phase, refer to these repos for source material and patterns:

| Path | What to look at |
|------|-----------------|
| `/Users/derekosgood/Documents/0_Git Repos/jules/.claude/` | Source of truth for: hook scripts (`hooks/safety-guard.sh`, `hooks/session-start.sh`, `hooks/notify-input.sh`), `settings.json` structure, skill format (look at `skills/build/`, `skills/debug/`, `skills/agent-browser/`, `skills/wrap-up/`, `skills/skill-creator/` — full directories with `references/`, `templates/`, `scripts/`) |
| `/Users/derekosgood/Documents/0_Git Repos/jules/CLAUDE.md` | Pattern for slim CLAUDE.md with `@`-imports for profiles (we'll mirror this for `@AGENTS.md` + `@docs/standards/*`) |
| `/Users/derekosgood/Documents/0_Git Repos/claude-code-best-practice/.claude/` | Hook config pattern (`hooks/config/hooks-config.json` for toggleable hooks), Command → Agent → Skills orchestration demo (`commands/weather-orchestrator.md` + `agents/weather.md` + `skills/weather-*/`) |
| `/Users/derekosgood/Documents/0_Git Repos/claude-code-best-practice/.claude/hooks/HOOKS-README.md` | Documentation for all 9 Claude Code hook events |
| `/Users/derekosgood/Documents/0_Git Repos/My-CC-Template/vibe-coding-prompts/` | Original workflow prompts being ported into skills |
| `/Users/derekosgood/Documents/0_Git Repos/My-CC-Template/AGENTS.md` | Source of all standards content being extracted to `docs/standards/` |

**Skills to copy verbatim from jules:** `agent-browser/`, `skill-creator/`. Both are self-contained with their own references and scripts.

**Skills to adapt from jules:** `debug/` (strip CI/signing-pipeline examples, keep methodology), `wrap-up/` (rename to `end-session`, simplify session-report destination), `build/` (cherry-pick the scope→design→plan→execute→ship structure for our `implement` skill).

---

## Goal

Turn this template from a manual prompt-pasting workflow (`vibe-coding-prompts/`) into a Claude Code-native template with enforced safety, model-invokable skills, and automated documentation maintenance — while preserving cross-tool compatibility (Cursor, Codex) via `AGENTS.md`.

## Constraints / non-negotiables

1. **Preserve all existing `docs/` files.** product_spec, architecture, decision_log, project_status, changelog, Features/ all stay. Their formats are good.
2. **Don't lose `AGENTS.md` content.** Slim it for context efficiency, but extract everything to `docs/standards/` rather than delete. Cursor/Codex still need to be able to read the principles.
3. **Coding-focused only.** No content/social/email/etc. skills from jules.
4. **Cross-tool compatible at the principles layer.** `AGENTS.md` stays the universal source of truth. `.claude/` is Claude Code-specific enhancement on top.
5. **Don't reinvent built-in skills/agents.** Use the harness's `simplify`, `review`, `security-review`, `init`, `feature-dev:code-explorer`, `feature-dev:code-architect`, `feature-dev:code-reviewer`, `Explore`. Compose, don't duplicate.
6. **Templates live with the skills that use them.** Feature doc template, product spec template, etc. move into `.claude/skills/<skill>/references/` rather than `docs/`. The `docs/` directory holds *instances* (filled-out specs), not templates.

---

## Target Architecture

### File hierarchy (target end state)

```
My-CC-Template/
├── .claude/                              # NEW (was missing entirely)
│   ├── settings.json                     # permissions (allow/deny), hooks wiring, env
│   ├── settings.local.json.example       # gitignored personal overrides template
│   ├── skills/                           # 11 skills, all user- and model-invocable
│   │   ├── plan/
│   │   │   ├── SKILL.md
│   │   │   └── references/
│   │   │       └── feature-template.md   # moved from docs/feature_doc_template.md
│   │   ├── implement/SKILL.md            # was "build" — implements ONE task atomically
│   │   ├── build/SKILL.md                # NEW — orchestrator: plan → implement → test via subagents
│   │   ├── test/SKILL.md
│   │   ├── ship/SKILL.md
│   │   ├── debug/SKILL.md
│   │   ├── ux-review/SKILL.md
│   │   ├── new-project/                  # was "onboard"
│   │   │   ├── SKILL.md
│   │   │   └── references/
│   │   │       ├── product-spec-template.md      # from setup-1
│   │   │       ├── architecture-template.md      # from setup-2
│   │   │       ├── env-template.md               # from setup-3
│   │   │       └── project-status-template.md    # from setup-4
│   │   ├── end-session/SKILL.md          # was "wrap-up"
│   │   ├── agent-browser/                # full directory copied verbatim from jules
│   │   └── skill-creator/                # full directory copied verbatim from jules
│   ├── agents/
│   │   └── doc-updater.md                # only project-specific agent
│   └── hooks/
│       ├── safety-guard.sh               # PreToolUse(Bash, WebFetch) — destructive cmd + secret blocker
│       ├── session-start.sh              # SessionStart — git pull --ff-only
│       ├── notify-input.sh               # Notification — macOS notification
│       └── doc-sync-check.sh             # Stop — soft reminder if src/ touched but no doc updates
├── AGENTS.md                             # slim to ~250 lines — universal cross-tool rulebook
├── CLAUDE.md                             # uppercase — imports AGENTS.md + Claude-Code-specific overlay
├── README.md                             # NEW — how to use this template
├── docs/                                 # all existing files preserved (templates moved out)
│   ├── product_spec.md                   # KEEP (instance, filled in via /new-project)
│   ├── architecture.md                   # KEEP (instance)
│   ├── decision_log.md                   # KEEP
│   ├── project_status.md                 # KEEP
│   ├── changelog.md                      # KEEP
│   ├── design-references.md              # NEW — captured during /new-project, used by /ux-review
│   ├── (ignore) brainstorm.md            # KEEP with "(ignore)" prefix per user preference
│   ├── (ignore) scratchpad.md            # KEEP with "(ignore)" prefix
│   ├── Features/                         # KEEP (instances)
│   └── standards/                        # NEW — extracted from AGENTS.md sections 5–9
│       ├── coding.md
│       ├── errors.md
│       ├── security.md
│       ├── testing.md
│       └── performance.md
└── (deleted) vibe-coding-prompts/        # ported into .claude/skills/, then removed
└── (deleted) docs/feature_doc_template.md  # moved into .claude/skills/plan/references/
└── (deleted) claude.md                   # lowercase replaced by uppercase CLAUDE.md
```

---

## Skills (11 total)

All skills use `user-invocable: true` so they can be called both via `/<name>` and auto-triggered by description match. No separate `commands/` directory — modern jules pattern.

### Workflow skills

| Skill | Replaces | Notes |
|-------|----------|-------|
| `plan` | `1-plan-milestone.md` + `2-plan-feature.md` | Altitude-aware. Detects milestone vs. feature scope from input and writes the appropriate output (project_status entry vs. Features/ doc). Uses `references/feature-template.md` (moved from `docs/`). |
| `implement` | `3-build-task.md` | **Renamed from `build`.** Atomic task implementation. One task at a time, human-gated checkpoint at the end. Unchanged philosophy. |
| `build` | NEW | **Meta-orchestrator.** Runs `/plan → /implement (per task) → /test` end-to-end via subagent dispatch — each phase in its own context to avoid window exhaustion. For simple work where you just want "do the thing" without manually chaining. Uses `Agent` tool to delegate phases; main thread only holds the orchestration state. |
| `test` | `4-test.md` | Feature-level testing pass. Runs existing tests, writes new ones, browser-verifies UI via `agent-browser`. Human-gated before ship. |
| `ship` | `5-finalize.md` | Per-feature finalize: lint/type-check, **delegate to built-in `simplify`**, **delegate to built-in `security-review`**, doc updates via `doc-updater` agent, conventional commit. |
| `end-session` | NEW (jules-derived) | **Renamed from `wrap-up`.** Per-**session** housekeeping: ensure changelog/project_status are current, capture any decisions to decision_log, leave clean handoff state. No separate "session report" file — everything goes into existing docs. |
| `new-project` | `setup-1` through `setup-4` | **Renamed from `onboard`.** New-project guided flow: interactive walk-through (uses `AskUserQuestion`) for product_spec → architecture → env → project_status, **plus capture of design reference apps for `/ux-review` to use later**. Templates live in `references/`. |

### Tool/methodology skills

| Skill | Source | Purpose |
|-------|--------|---------|
| `agent-browser` | jules verbatim (full directory) | Browser automation CLI. Used by `test`, `ux-review`, `build`. |
| `debug` | jules adapted | Root-cause-first methodology for actual bugs. Phase 1 investigate → Phase 2 pattern → Phase 3 hypothesis → Phase 4 fix. |
| `ux-review` | NEW | **Focus: usability and design polish, NOT primarily accessibility.** Evaluates: (a) usability — does the flow make sense, (b) design polish — typography, spacing, color, motion feels tasteful, (c) consistency — matches other parts of the product OR matches reference example apps captured in `docs/design-references.md` during `/new-project`. Uses `agent-browser` to actually click through; default viewport desktop, project-configurable. |
| `skill-creator` | jules verbatim (full directory) | Meta-tool for evolving this template. Lets future-you add new skills with the eval/iterate workflow. |

### Dropped from earlier plans

- `update-fix` — redundant with `debug` + `implement` + `ship`.
- `simplify` (project version) — use built-in.
- `plan-milestone` + `plan-feature` as separate skills — merged into `plan`.
- 4 separate `setup-*` skills — merged into `new-project`.

### Built-in skills referenced in `AGENTS.md` routing (don't duplicate)

- `simplify` — invoked by `ship`
- `security-review` — invoked by `ship`
- `review` — for PR review
- `init` — downstream projects only

---

## The `build` orchestrator pattern (new)

This is the most novel piece. Worth spelling out so future sessions implement it correctly.

**Problem it solves:** running `/plan`, then 3-5 invocations of `/implement`, then `/test` in a single conversation eats the context window fast — every file Claude reads stays in context.

**Solution:** `/build <description>` orchestrates the same workflow but delegates each phase to subagents. Each agent gets a clean context window, does its job, returns a compact summary, exits.

**Flow:**
1. **Main thread:** receives `/build "add a dark mode toggle"`. Captures the task description.
2. **Main thread → planning subagent:** spawn `feature-dev:code-architect` (built-in) with the task. It returns a plan: list of atomic tasks + files to touch.
3. **Main thread:** presents plan, gets human approval.
4. **Main thread → implementation subagents (sequential):** for each task in the plan, spawn a fresh agent with just that task + relevant file context. Agent implements, returns summary + diff.
5. **Main thread → test subagent:** spawn agent to run tests + (if UI) agent-browser checks. Returns pass/fail + screenshots.
6. **Main thread:** presents the full result; user can `/ship` from a clean context.

**Key invariants:**
- Main thread never reads the full source files — only summaries from agents.
- Plan approval happens in main thread (human gate preserved).
- Each implementation subagent context is independent — no cross-contamination.
- If any phase fails, main thread surfaces the error and stops.

**When to use:** simple-to-medium tasks where the human doesn't need to be in the loop on every implementation step.
**When NOT to use:** complex/risky work where you want to review each task before the next.

---

## Documentation flow (clarifying the doc-sync mapping)

The template uses these existing docs (not creating new ones — answering open question #5):

| File | What it captures | Who updates it | When |
|------|------------------|----------------|------|
| `docs/changelog.md` | What code changed. **1-2 lines per entry**, grouped by version. Lightweight by design. | `doc-updater` agent | At `/ship` (per feature), at `/end-session` if any features completed |
| `docs/decision_log.md` | Architectural decisions with rationale + AI Instructions block (per AGENTS.md §11.3) | `doc-updater` agent | When `/ship` detects a non-obvious tradeoff was made, OR manually invoked when user makes a call mid-flow |
| `docs/project_status.md` | What's in-progress, what's done, what's next | `doc-updater` agent | At `/plan` (mark in-progress), at `/ship` (mark complete), at `/end-session` (housekeeping) |
| `docs/Features/<feature>.md` | Per-feature spec, task list, decisions for that feature | `plan` skill creates; `ship` finalizes | Created at `/plan`, updated throughout |

**The `doc-sync-check.sh` Stop hook:**
- Fires when Claude finishes a turn (Stop event)
- Checks: did this session touch files in `src/` (or other code dirs) AND touch *neither* `changelog.md` *nor* `project_status.md`?
- If yes → soft reminder to Claude: "you changed code but didn't update docs — consider invoking `doc-updater`"
- If no → silent
- **Anti-nag rules:**
  - Only fires once per session (not on every Stop)
  - Skipped if the only edits were to `.md`, `.json` config, or test files
  - Skipped if `/plan` or `/end-session` ran this session (those have their own doc handling)
  - Threshold: only fires after 3+ source files changed (not single-file tweaks)

**The `doc-updater` agent:**
- Inputs: git diff (from `git diff HEAD~1` or staged), context about what was built
- Outputs: PR-style additions to changelog (1-2 lines, "Added X", "Fixed Y"), decision_log if applicable, project_status state changes
- Constraint: brevity is enforced via prompt — agent is told to write the *minimum* useful entry, not paragraphs

**No new doc files needed.** This setup uses changelog + decision_log + project_status exactly as designed in AGENTS.md §11.

---

## Agents (1 total)

Down from the planned 4. The harness already provides `feature-dev:code-explorer`, `feature-dev:code-architect`, `feature-dev:code-reviewer`, and `Explore` — all read CLAUDE.md/AGENTS.md so they're project-aware automatically. Don't reinvent.

| Agent | Purpose |
|-------|---------|
| `doc-updater` | Takes a diff + commit message and updates `changelog.md` (1-2 line entries), `project_status.md` (state changes), `decision_log.md` (when applicable). Invoked by `ship` and by the `doc-sync-check.sh` Stop hook. No built-in equivalent. |

`AGENTS.md` routing table will explicitly tell Claude when to use built-in agents vs. when to invoke `doc-updater`.

---

## Hooks (4 total)

Three from jules (battle-tested), one new (project-specific).

| Hook | Event | Purpose | Source |
|------|-------|---------|--------|
| `safety-guard.sh` | PreToolUse(Bash, WebFetch) | Block: `rm`, `sudo`, force-push, `git add .`/`git add -A`, secret literals (AWS/GH/Anthropic/OpenAI keys), system-dir writes, `curl ... \| sh`, `.env` redirect overwrites. Enforces AGENTS.md §3 (currently aspirational). | jules verbatim |
| `session-start.sh` | SessionStart | `git pull --ff-only` to avoid stale-branch surprises. | jules verbatim |
| `notify-input.sh` | Notification | macOS notification when Claude needs input. | jules verbatim |
| `doc-sync-check.sh` | Stop | Anti-nag soft reminder per the rules in "Documentation flow" above. | NEW |

Plus declarative `permissions.deny` in `settings.json` mirroring the deny patterns (defense in depth).

### Hook portability (answering question #8)

**Yes, hooks are per-project and transferable.** They live in `.claude/hooks/` inside the project directory. Anyone who clones this template gets the hooks automatically. They reference `$CLAUDE_PROJECT_DIR` for paths, so they Just Work in any project that has them in `.claude/hooks/`.

**Dependencies (document in README):**
- `bash` (assumed everywhere)
- `jq` (used by safety-guard.sh to parse hook input JSON) — `brew install jq` on macOS
- `osascript` (used by notify-input.sh on macOS for native notifications) — built-in on macOS
- `git` (used by session-start.sh and doc-sync-check.sh)

On Linux/Windows, `notify-input.sh` falls back to OSC 9 escape (already handled in jules's version). Safety-guard works anywhere with bash + jq.

---

## AGENTS.md restructure

**Current:** ~620 lines, always loaded into context every turn. Encyclopedic.

**Target:** ~250 lines always loaded. Reference material extracted to `docs/standards/`, accessed on demand.

### What stays in AGENTS.md (always loaded)

- §1 Project Identity (architecture diagram, design principles)
- §2 Documentation Map
- §3 Critical Constraints — keep the headlines, one-liner per bullet (e.g., "Never commit secrets — use env vars. See `docs/standards/security.md`.")
- §4 Development Workflow (git standards, pre-commit checklist)
- §5 Coding Standards — keep §5.1 General Principles only. Extract rest to `docs/standards/coding.md`. Reference inline.
- §6 Error Handling — keep §6.1 Principles only. Extract patterns to `docs/standards/errors.md`.
- §7 Security — keep §7.1 + §7.2 short summary. Extract checklist to `docs/standards/security.md`.
- §8 Testing — keep §8.1 + §8.2 short summary. Extract examples to `docs/standards/testing.md`.
- §9 Performance — keep one-paragraph summary. Extract details to `docs/standards/performance.md`.
- §10 AI Assistant Behavior — keep entirely. Critical for every turn.
- §11 Documentation Maintenance — keep the trigger table and post-action checklist.
- §12 Quick Reference Commands — keep
- **NEW: §13 Skill Routing Table** — maps user intents to skills (`/plan`, `/implement`, `/build`, `/ship`, etc.) and built-ins (`/simplify`, `/security-review`).
- **NEW: §14 Cross-Tool Compatibility note** — explains that `.claude/` is Claude Code-only; AGENTS.md is the universal layer.

### What moves to `docs/standards/`

- `docs/standards/coding.md` — current AGENTS.md §5.2–5.6
- `docs/standards/errors.md` — current §6.2–6.3
- `docs/standards/security.md` — current §7.3
- `docs/standards/testing.md` — current §8.3
- `docs/standards/performance.md` — current §9.1–9.3

### CLAUDE.md (Claude Code-specific overlay)

Replaces lowercase `claude.md`. Short file:
- `@AGENTS.md` to import the universal rulebook
- Claude Code-specific notes: skill routing maps to `.claude/skills/`, hooks are wired in `.claude/settings.json`
- Pointer to this `RESTRUCTURE_PLAN.md` while restructure is in progress

---

## Migration Phases

Each phase is self-contained and can be done in a separate session. Reference this doc + the "Reference repos" section at the start of each.

### Phase 1: Foundation (no behavior change yet)
- [ ] Create `.claude/settings.json` with permissions (allow/deny) mirroring AGENTS.md §3 — copy structure from jules's `.claude/settings.json`
- [ ] Create `.claude/settings.local.json.example` template
- [ ] Add `.gitignore` entries: `.claude/settings.local.json`, `.DS_Store`
- [ ] Rename `claude.md` → `CLAUDE.md`, make it import `@AGENTS.md`

### Phase 2: Hooks
- [ ] Copy `.claude/hooks/safety-guard.sh` from `jules/.claude/hooks/safety-guard.sh` verbatim
- [ ] Copy `.claude/hooks/session-start.sh` from jules verbatim
- [ ] Copy `.claude/hooks/notify-input.sh` from jules verbatim
- [ ] Write `.claude/hooks/doc-sync-check.sh` (NEW — implement anti-nag rules)
- [ ] Wire all 4 hooks in `settings.json`
- [ ] Test: try a blocked command, verify it's rejected
- [ ] Document hook dependencies in README (jq, osascript, etc.)

### Phase 3: AGENTS.md restructure
- [x] Create `docs/standards/` directory
- [x] Extract §5.2–5.6 → `docs/standards/coding.md`
- [x] Extract §6.2–6.3 → `docs/standards/errors.md`
- [x] Extract §7.3 → `docs/standards/security.md`
- [x] Extract §8.3 → `docs/standards/testing.md`
- [x] Extract §9.1–9.3 → `docs/standards/performance.md`
- [x] Slim AGENTS.md, add references to `docs/standards/*` (kept as plain markdown links — universal across Cursor/Codex/Claude Code, not Claude-only `@`-imports, since the goal is on-demand loading rather than always-loaded)
- [x] Add §13 Skill Routing Table (populated with all planned skills + harness built-ins; project skills marked _pending_ per phase)
- [x] Add §14 Cross-Tool Compatibility note
- [x] Verify line count: 343 (above the ~250 target — §10 + §11 + new §13 routing table + §14 cross-tool note are all load-bearing keeps; further slimming would cut required content)
- Existing §13 Project-Specific Guidelines renumbered to §15

### Phase 4: Workflow skills
- [x] `.claude/skills/plan/SKILL.md` — merge plan-milestone + plan-feature with altitude detection
- [x] `.claude/skills/plan/references/feature-template.md` — move `docs/feature_doc_template.md` here
- [x] Delete `docs/feature_doc_template.md` (moved via `mv`, not deleted standalone)
- [x] `.claude/skills/implement/SKILL.md` — port build-task
- [x] `.claude/skills/test/SKILL.md` — port test
- [x] `.claude/skills/ship/SKILL.md` — port finalize, add delegations to built-in `simplify` and `security-review`, invoke `doc-updater` agent (inline fallback noted until Phase 8)
- [x] `.claude/skills/end-session/SKILL.md` — adapt jules wrap-up; trim to "ensure docs are current, capture decisions, clean handoff" (no separate session report file)
- [x] Update AGENTS.md §13 routing table — five Phase 4 skills marked available; `/build` remains pending Phase 5

### Phase 5: Build orchestrator
- [x] `.claude/skills/build/SKILL.md` — implement the orchestrator pattern from this doc's "build orchestrator pattern" section
- [ ] Test on a small real task end-to-end; verify each phase actually runs in a subagent context (deferred — needs a real feature to dispatch against)

### Phase 6: New-project skill
- [x] `.claude/skills/new-project/SKILL.md` — orchestrator with interactive `AskUserQuestion` flow
- [x] `.claude/skills/new-project/references/product-spec-template.md` — port from `vibe-coding-prompts/setup-1-product_spec.md`
- [x] `.claude/skills/new-project/references/architecture-template.md` — port from setup-2
- [x] `.claude/skills/new-project/references/env-template.md` — port from setup-3
- [x] `.claude/skills/new-project/references/project-status-template.md` — port from setup-4
- [x] **Design-reference capture step** wired in as Phase 5 of `/new-project`; writes `docs/design-references.md` for `/ux-review` to consume
- [ ] Test on a fresh clone (deferred — needs a fresh clone to validate end-to-end)

### Phase 7: Tool/methodology skills
- [x] Copy `.claude/skills/agent-browser/` from jules verbatim (full directory: SKILL.md + references/ + templates/)
- [x] `.claude/skills/debug/SKILL.md` — port from jules, strip CI/signing-pipeline examples (replaced macOS codesign example with a generic web-app boundary-logging example)
- [x] `.claude/skills/ux-review/SKILL.md` — write from scratch with the focus described above (usability + polish + consistency-with-references; NOT primarily accessibility)
- [x] Copy `.claude/skills/skill-creator/` from jules verbatim (full directory)

### Phase 8: Agents
- [x] `.claude/agents/doc-updater.md` — written. Inputs: git diff + one-line summary. Outputs: brevity-enforced changelog entries, project_status state changes, decision_log entries when warranted (with mandatory `AI Instructions` block per AGENTS.md §11.2). Hard limits set in the prompt (≤2-line changelog entries, ≤8-line decision entries excluding AI Instructions).
- [x] AGENTS.md §13 routing table — added `doc-updater` row.
- [x] `ship` skill — Phase 8 pending note removed; now delegates to `doc-updater` directly.

### Phase 9: README
- [x] `README.md` — written. Covers: what the template is, quick start (clone → install jq/git → `/new-project` → optional local overrides), skill list with one-line descriptions, agents (project-specific `doc-updater` + reliance on built-in `feature-dev:*`/`Explore`), hooks table with dependencies, documentation flow, cross-tool compatibility matrix, "where to look for what" lookup table, customization tips.
- [x] CLAUDE.md — restructure-in-progress callout replaced with a pointer to README.md and `/new-project`; agents directory mentioned alongside skills/templates.

### Phase 10: Cleanup
- [x] Delete `vibe-coding-prompts/` (removed via `git rm -r`)
- [x] Delete `claude.md` lowercase (done in Phase 1)
- [x] Delete `docs/feature_doc_template.md` (moved into `.claude/skills/plan/references/` in Phase 4)
- [ ] Delete this `RESTRUCTURE_PLAN.md` — **deferred per user**, kept for reference until template is exercised end-to-end and the deferred Phase 5/6 verification tasks are completed

---

## Key Decisions Made (with rationale)

These are the load-bearing decisions. If a future session wants to change one, read the rationale first.

| Decision | Rationale |
|----------|-----------|
| **Everything is a skill, no `commands/` directory** | Modern jules pattern. Skills with `user-invocable: true` work as both slash commands AND auto-triggers. |
| **Rename `build` → `implement`; add new `build` as orchestrator** | `implement` is more accurate (one task at a time). New `build` solves context-window exhaustion by delegating phases to subagents — gives a one-shot end-to-end option for simple work. |
| **Merge `plan-milestone` + `plan-feature` → `/plan`** | Same workflow at different altitudes. Skill detects scope from input. |
| **Merge 4 setup prompts → `/new-project`** | Sequential, run once. Single guided flow with `AskUserQuestion` is better UX. |
| **Drop `update-fix`** | Redundant with `debug` + `implement` + `ship`. |
| **Split `finalize` → `ship` (per-feature) + `end-session` (per-session)** | Different scopes, different triggers. |
| **Templates live with skills, not `docs/`** | Progressive disclosure. Templates only loaded when the relevant skill triggers. `docs/` holds instances. |
| **Use built-in `simplify`, `security-review`, `review`, `init`** | Already in the harness. `ship` delegates rather than reinventing. |
| **Use built-in `feature-dev:*` agents** | Already project-aware via CLAUDE.md/AGENTS.md. Only `doc-updater` is genuinely project-specific. |
| **Slim AGENTS.md but extract everything to `docs/standards/`** | Context efficiency every turn. Nothing lost — extracted files still loadable on demand and readable by Cursor/Codex. |
| **`AGENTS.md` cross-tool universal; `.claude/` Claude Code-only** | Cursor/Codex read AGENTS.md. They can't use hooks/skills/agents. Split keeps principles portable. |
| **Doc updates use existing changelog + decision_log + project_status — no new files** | Lightweight. End-session and ship just update what's already there. Hook is anti-nag (single-fire, threshold-gated). |
| **`ux-review` is usability + polish + consistency, NOT primarily accessibility** | User preference. Reference apps captured during `/new-project` are the consistency benchmark. |
| **Default ux-review viewport: desktop, project-configurable** | Resolves open question #3. |

---

## Resolved Open Questions

| Q | Resolution |
|---|------------|
| `new-project` interactivity | Use `AskUserQuestion` for each step (asking is better than guessing). |
| Doc-update bloat / nag fatigue | 1-2 line changelog entries enforced by agent prompt. Hook fires once per session, only after 3+ source files changed, and is skipped if `/plan` or `/end-session` already ran. |
| `ux-review` viewports | Default desktop, project-configurable. Reference apps captured in `docs/design-references.md` during `/new-project`. |
| `skill-creator` retention | Keep — meta-tool for template evolution. |
| `end-session` report destination | No new file. Updates existing changelog + decision_log + project_status. |

---

## What this plan does NOT change

- All existing files in `docs/` (product_spec, architecture, decision_log, project_status, changelog, Features/, the `(ignore) brainstorm.md` and `(ignore) scratchpad.md` markers — kept with the prefix per user preference)
- The 6-step workflow philosophy (plan → implement → test → ship, with human gates between each) — `build` orchestrator is an *additional* one-shot path, not a replacement
- The AGENTS.md §3 constraints themselves (only the format/location changes — every rule is preserved)
- The §11 documentation-maintenance mandate (only the enforcement mechanism changes — adds hook + agent)
