# Install-Harness Plan (temporary planning doc)

> Status: proposal, awaiting review. Delete this file once the plan is implemented or rejected.
> Date: 2026-05-03

## Goal

Make this template's harness (skills, hooks, agents, docs scaffold, AI rulebook) drop-in-installable into any other repo on the user's machine, while:

1. Keeping the **template repo as the editable source of truth** — so the user can keep editing skills in the IDE the way they do today.
2. Supporting **two install paths** — fresh project vs. existing-codebase backfill.
3. Optionally keeping the install **invisible to coworkers** when the user wants a solo setup on a shared repo.

---

## 1. Architecture overview

Three moving pieces:

### 1.1 Source of truth: this template repo

Everything stays here, version-controlled, editable in the IDE exactly as today:

- `.claude/skills/*` — the 11 project skills
- `.claude/agents/*` — `doc-updater`
- `.claude/hooks/*` — the four hooks
- `.claude/settings.json` — hook wiring
- `AGENTS.md`, `CLAUDE.md` — AI rulebook + Claude Code overlay
- `docs/standards/*` — universal reference docs
- `docs/*.md` — empty templates (product_spec, architecture, decision_log, project_status, changelog, marketing-strategy)

### 1.2 User-level mirror: `~/.claude/` via symlinks

For skills/agents/hooks to work in *every* repo without copying, mirror them into `~/.claude/` as symlinks pointing back to this template repo:

```
~/.claude/skills/plan        → ~/code/My-CC-Template/.claude/skills/plan
~/.claude/skills/implement   → ~/code/My-CC-Template/.claude/skills/implement
... (per skill)
~/.claude/agents/doc-updater → ~/code/My-CC-Template/.claude/agents/doc-updater.md
~/.claude/hooks/safety-guard.sh → ~/code/My-CC-Template/.claude/hooks/safety-guard.sh
... (per hook)
```

**Why per-item symlinks instead of whole-directory symlinks:**
- Lets the user mix template skills with other user-level skills they install separately (e.g., upstream marketing plugin).
- Avoids clobbering an existing `~/.claude/` if it's already populated.
- Each symlink is independent and can be removed without affecting siblings.

**Why this preserves IDE editability:**
- The user opens the template repo in their IDE as today. Edits land in the real file. Claude (running in any other repo) follows the symlink and sees the edit immediately. No sync step, no rebuild.

**Hooks caveat:** Hooks referenced by `~/.claude/settings.json` must use absolute paths or `$HOME/.claude/hooks/...` paths. Settings file gets a copy (not a symlink) so the user can tune per-machine without polluting the template.

### 1.3 Per-repo files: `AGENTS.md`, `CLAUDE.md`, `docs/`

These are project-specific by nature — they describe *that* project's stack, decisions, and status. They live in the target repo, not in `~/.claude/`. The install paths below decide how they get populated.

---

## 2. The install skill: `install-cc-harness`

Lives at `~/.claude/skills/install-cc-harness/SKILL.md` (also symlinked back to `My-CC-Template/.claude/skills/install-cc-harness/` so it's editable in the IDE alongside the others).

### 2.1 Invocation

```
cd ~/code/some-other-repo
claude
> /install-cc-harness
```

The skill asks **two questions** up front via `AskUserQuestion`:

1. **Mode:** `new project` (fresh repo, fill in via interactive walkthrough) or `existing project` (backfill docs from existing code).
2. **Visibility:** `team` (commit harness files so coworkers see them) or `solo` (add to `.git/info/exclude` so only this clone sees them).

Then it branches.

### 2.2 Path A — New project

For a freshly cloned/created repo with no real code yet, or where the user wants a clean slate.

Steps:
1. Copy `AGENTS.md`, `CLAUDE.md`, `docs/` (full scaffold including empty templates), `.agents/` from the template repo.
2. If `team` mode: append `.claude/settings.local.json` and hook config to the repo's `.gitignore`.
3. If `solo` mode: add `AGENTS.md`, `CLAUDE.md`, `docs/`, `.agents/` to `.git/info/exclude`.
4. **Hand off to the existing `/new-project` skill** — it already does the interactive placeholder fill (project identity, tech stack, objectives, dev commands, personas). No need to duplicate logic.
5. Done.

### 2.3 Path B — Existing project (backfill)

For a repo with real code, README, package manifests, and history. The hard case.

Steps:
1. Copy the same files as Path A. Leave `docs/*.md` as empty templates.
2. If `team` / `solo`: same gitignore vs `.git/info/exclude` choice.
3. **Run a layered backfill** — *not* `/new-project`, which is wrong for this case:
   - **Pass 1 (main agent, cheap reads):** README, top-level package manifest (`package.json` / `pyproject.toml` / `Cargo.toml` / `go.mod`), top-level folder list, root config files. ~5k tokens.
   - **Pass 2 (parallel `Explore` subagents):** one per major top-level source dir. Each gets a tight prompt: *"Identify tech stack, key patterns, and 5–10 representative files in `<dir>`. Report under 500 words."* Subagent context windows stay isolated — only summaries return.
   - **Pass 3 (main agent synthesis):** write `docs/architecture.md` (real stack, layout, patterns), `docs/product_spec.md` (paragraph + main features inferred from README/code), `docs/project_status.md` (just "imported on YYYY-MM-DD; current focus: TBD").
   - **Pass 4 (user review):** present the generated docs and ask the user to correct anything wrong before saving.
4. Skip `decision_log.md` and `changelog.md` history — start them forward from today.
5. Done.

**Skipped/unchanged:** `decision_log.md` (empty), `changelog.md` (empty), `marketing-strategy.md` (empty). These grow forward.

### 2.4 Bootstrap step (run once, before either path)

Before the first install, the skill checks whether the user-level mirror exists. If not, it offers to set it up:

1. Detect template repo location (default: ask user, or read from a known path like `~/.cc-template-source`).
2. For each item under `<template>/.claude/skills/`, `<template>/.claude/agents/`, `<template>/.claude/hooks/`: create a symlink in `~/.claude/<same path>`.
3. Copy (not symlink) `<template>/.claude/settings.json` to `~/.claude/settings.json`, rewriting hook paths to absolute `$HOME/.claude/hooks/...` form. If `~/.claude/settings.json` already exists, *merge* the `hooks` block rather than overwrite.
4. Save the template repo path to `~/.cc-template-source` so future invocations skip this step.

This bootstrap is idempotent — running twice is a no-op.

---

## 3. Solo-mode mechanics (invisibility from coworkers)

When the user picks `solo`, the install skill:

1. Adds these entries to `.git/info/exclude` (the per-clone git ignore, never committed):
   ```
   /AGENTS.md
   /CLAUDE.md
   /docs/
   /.claude/
   /.agents/
   ```
2. Skips creating `<repo>/.claude/settings.json` entirely — relies on `~/.claude/settings.json` for hooks.
3. Optionally creates `<repo>/.claude/` only if needed (e.g., for project-specific skill overrides). Most repos won't need this.

Result: `git status` is clean for the user *and* coworkers. Claude Code sees all the files. Coworkers never know.

**Trade-off:** if the user later wants to share the harness with the team, they'd need to manually `git add` each file (since `.git/info/exclude` blocks staging). Worth flagging in the skill output.

---

## 4. The IDE-editability question

Concrete answer: **edit in the template repo as today.** The symlinks make every edit instantly live everywhere.

Workflow:
1. User opens `~/code/My-CC-Template/` in their IDE — same as today.
2. User edits `.claude/skills/plan/SKILL.md`.
3. Claude in any other repo invokes `/plan` — reads through the `~/.claude/skills/plan` symlink → resolves to the freshly edited file.
4. No copy, no rebuild, no version bump.

The template repo stays the canonical version-controlled source. `git log` on `~/code/My-CC-Template/` shows the full skill history. `~/.claude/` is just a viewport.

**One gotcha:** if the user moves or renames the template repo, all symlinks break. The bootstrap step writes the template path to `~/.cc-template-source` so a `repair` subcommand can rebuild the symlinks if needed.

---

## 5. Open decisions

Things to settle before implementing:

1. **Skill name:** `/install-cc-harness`? `/setup-harness`? `/cc-install`? (The `cc-` prefix avoids collision with future built-in `/install`.)
2. **Should the bootstrap step be a separate skill** (`/cc-bootstrap`) so the user runs it explicitly once, instead of being auto-detected on first install? Cleaner separation, slightly more friction.
3. **Where to store the template path** — `~/.cc-template-source` (plain file)? `~/.claude/cc-template-source` (alongside settings)? Env var?
4. **Hook merging strategy when `~/.claude/settings.json` already exists** — append, prompt, or fail? Append is friendly but can produce duplicates if run twice; idempotency requires hashing or naming hooks.
5. **Should `solo` mode be the default or `team`?** Team is friendlier for adoption; solo is friendlier for trying the template on existing repos without commitment. Probably ask each time, no default.
6. **Marketing skills** — out of scope for this install skill (they come from a separate plugin). But worth a one-line note in the skill output: *"For marketing skills, also run: /plugin install marketing-skills@marketingskills"*.

---

## 6. Implementation order (when ready to build)

1. Create `.claude/skills/install-cc-harness/SKILL.md` in this repo (so it's editable here and gets symlinked into `~/.claude/skills/` like the others).
2. Implement the bootstrap step (symlink generator + settings.json merger).
3. Implement Path A (new-project install) — mostly delegates to `/new-project`.
4. Implement Path B (existing-project backfill) — the layered Explore-subagent flow.
5. Add a `repair` subcommand for broken symlinks (post-template-move).
6. Test on: (a) a freshly cloned empty repo, (b) a small existing TS repo, (c) a large existing monorepo.
7. Document in `README.md` under a new "Using this in other repos" section.
8. Delete this planning file.

---

## 7. What this plan deliberately doesn't do

- **No npm package.** No registry. The template repo + symlinks is the distribution mechanism.
- **No auto-update.** If the template repo gets new skills, the user pulls in this repo and the symlinks pick them up. New skills need a manual symlink add (or a `refresh` subcommand — TBD).
- **No coworker propagation.** If a coworker wants the same setup, they install it on their machine independently. The harness is a personal productivity layer, not a shared dep.
- **No backfill of `decision_log.md`.** Past decisions weren't logged; pretending to recover them produces fiction. Start forward.
