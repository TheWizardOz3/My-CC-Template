# My-CC-Template

A Claude Code-native project template. Drop into a fresh repo and you get: enforced safety rails, a model-invokable skill workflow (plan → implement → test → ship), automated documentation maintenance, and cross-tool compatibility with Cursor and Codex via [AGENTS.md](AGENTS.md).

> Built on patterns from [Claude Code best practices](https://www.anthropic.com/engineering/claude-code-best-practices) and battle-tested skill/hook setups borrowed (with permission) from upstream reference repos.

---

## What's in here

```
.
├── .claude/                  # Claude Code-only: skills, agents, hooks, settings
│   ├── settings.json         # permissions + hooks wiring
│   ├── hooks/                # safety guard, session start, notify, doc-sync
│   ├── skills/               # 12 user- and model-invocable workflow skills
│   └── agents/doc-updater.md # the one project-specific subagent
├── .agents/                  # cross-agent location for product-marketing-context.md
├── AGENTS.md                 # universal rulebook (Claude Code, Cursor, Codex)
├── CLAUDE.md                 # Claude Code overlay — imports AGENTS.md
├── docs/                     # filled in via /new-project; updated as you build
│   ├── product_spec.md       # what you're building
│   ├── architecture.md       # how you're building it
│   ├── decision_log.md       # why — with AI Instructions for future work
│   ├── project_status.md     # current state (read this first each session)
│   ├── changelog.md          # what changed
│   ├── design-references.md  # benchmark apps for /ux-review (optional)
│   ├── marketing-strategy.md # rolling marketing notes (in-progress, completed, ideas)
│   ├── Features/             # per-feature specs and task lists
│   └── standards/            # coding/errors/security/testing/perf — load on demand
├── marketing/                # output dir for marketing collateral (copy/emails/ads/assets)
└── README.md                 # this file
```

---

## Quick start

### 1. Clone

```bash
git clone <this-repo> my-new-project
cd my-new-project
rm -rf .git && git init
```

### 2. Install dependencies

The hooks rely on a few command-line tools:

| Tool | Used by | Required? | Install |
|------|---------|-----------|---------|
| `bash` | all hooks | yes | preinstalled |
| `jq` | `safety-guard.sh`, `doc-sync-check.sh` | **yes** — hooks fail closed without it | `brew install jq` (macOS) / `apt install jq` (Linux) |
| `git` | `session-start.sh`, `doc-sync-check.sh` | yes | preinstalled |
| `osascript` | `notify-input.sh` (macOS only) | optional — falls back to OSC 9 elsewhere | preinstalled on macOS |

> Without `jq`, the `PreToolUse` safety guard errors and Claude Code blocks every Bash/WebFetch call. Install it before you start.

### 3. Open in Claude Code and run `/new-project`

```
/new-project
```

This walks you through (interactively, via `AskUserQuestion`):

1. **product_spec** — what you're building, who it's for, what's in scope
2. **architecture** — tech stack, system design, key patterns
3. **env** — required environment variables, secrets layout
4. **project_status** — first milestone, in-progress / next-up lists
5. **design-references** — UI benchmark apps for `/ux-review` to compare against (optional)

It fills in the placeholders in `AGENTS.md` and `docs/*` and writes `docs/design-references.md`. Run it once per project.

### 4. Personal overrides (optional)

Copy `.claude/settings.local.json.example` → `.claude/settings.local.json` (gitignored) for per-developer tweaks like disabling a hook locally.

---

## How it works

### Skills

Every workflow lives in `.claude/skills/`. Each is **user-invocable as a slash command** and **auto-triggers** on intent match (descriptions in each `SKILL.md`).

| Skill | What it does |
|-------|--------------|
| `/plan` | Plan a feature or milestone. Altitude-aware — detects scope from input. Writes to `docs/Features/<name>.md` (feature) or `docs/project_status.md` (milestone). |
| `/implement` | Implement **one** atomic task from a planned feature. Human-gated checkpoint at the end. |
| `/build` | End-to-end orchestrator: `/plan → /implement (per task) → /test`, each phase delegated to a fresh subagent so the main thread's context stays clean. Use for simple-to-medium work where you want one shot. |
| `/test` | Feature-level testing pass. Runs existing tests, writes new ones, browser-verifies UI via `/agent-browser`. |
| `/ship` | Finalize a feature: lint, type-check, delegate to built-in `/simplify` and `/security-review`, run the `doc-updater` agent, conventional commit. |
| `/end-session` | Per-session housekeeping. Confirms docs are current, captures decisions, leaves a clean handoff. |
| `/new-project` | Interactive bootstrap (run once per project). |
| `/debug` | Root-cause-first debugging methodology — reproduce, hypothesize, test one variable at a time. |
| `/ux-review` | Evaluate a UI surface for usability, polish, and consistency with `docs/design-references.md`. Drives a real browser. |
| `/agent-browser` | Browser automation primitive used by `/test` and `/ux-review`. |
| `/skill-creator` | Meta-tool for adding or evolving skills in this template. |
| `/marketing-context` | Bridge skill — pre-populates `.agents/product-marketing-context.md` from dev docs and asks for the marketing-only gaps. Foundation for every plugin marketing skill. See [Marketing capabilities](#marketing-capabilities). |

The full intent-to-skill routing table — including built-in skills like `/simplify`, `/security-review`, and `/review` that are delegated to but not duplicated, plus the 39 plugin marketing skills — lives in [AGENTS.md §13](AGENTS.md#13-skill-routing-table).

### Agents

The harness already provides [`feature-dev:code-explorer`, `feature-dev:code-architect`, `feature-dev:code-reviewer`, and `Explore`](https://docs.anthropic.com) — they read `CLAUDE.md`/`AGENTS.md`, so they're project-aware automatically. We don't reinvent them.

The one **project-specific** agent:

| Agent | Purpose |
|-------|---------|
| [`doc-updater`](.claude/agents/doc-updater.md) | Takes a git diff plus a one-line summary and applies brevity-enforced updates to `changelog.md`, `project_status.md`, and (when warranted) `decision_log.md`. Invoked by `/ship` and by the `doc-sync-check` hook. |

### Hooks

Wired in [.claude/settings.json](.claude/settings.json). See [.claude/hooks/README.md](.claude/hooks/README.md) for full detail and dependencies.

| Hook | Event | Purpose |
|------|-------|---------|
| `safety-guard.sh` | `PreToolUse` (Bash, WebFetch) | Blocks destructive commands (`rm`, `sudo`, force-push, broad `git add`, system-dir writes, `curl ... \| sh`, `.env` overwrites) and refuses to send commands containing literal API keys/secrets. Mirrors AGENTS.md §3. |
| `session-start.sh` | `SessionStart` | Runs `git pull --ff-only` so a new session doesn't start on a stale branch. |
| `notify-input.sh` | `Notification` | macOS native notification (or OSC 9 escape elsewhere) when Claude is awaiting input. |
| `doc-sync-check.sh` | `Stop` | Anti-nag soft reminder to update `changelog.md` / `project_status.md` when a session has touched source files but not the docs. Fires at most once per session, only when 3+ source files changed, skipped if `/plan` or `/end-session` ran. |

In addition, `settings.json` declares a `permissions.deny` list mirroring the safety-guard patterns — defense in depth.

### Documentation flow

The template treats docs as **part of completing the work, not a separate task**. The mechanics:

- `/plan` — creates `docs/Features/<name>.md`, marks the feature **In Progress** in `project_status.md`.
- `/ship` — at the end of a feature, invokes the `doc-updater` agent to write a 1–2 line `changelog.md` entry, move the feature to **Completed**, and (only when warranted) add a `decision_log.md` entry with an **AI Instructions** block per [AGENTS.md §11.2](AGENTS.md#112-documentation-standards).
- `/end-session` — sweeps for missed updates and decisions before handoff. No separate session-report file — everything goes into the existing docs.
- `doc-sync-check.sh` — surfaces missed updates as a soft reminder (never a block).

The `doc-updater` agent enforces brevity in its prompt: changelog entries are ≤2 lines, not paragraphs.

---

## Marketing capabilities

Beyond shipping the app, the template can produce marketing collateral and (optionally) host a marketing site rooted in the actual product being built. The marketing playbooks themselves are not vendored — they come from the upstream [`coreyhaines31/marketingskills`](https://github.com/coreyhaines31/marketingskills) plugin, installed once per machine and shared across every project.

### Prerequisites

| Requirement | Why | Install |
|-------------|-----|---------|
| Node 18+ | Marketing tools include zero-dep Node CLIs (GA4 pulls, Stripe queries, Resend sends, etc.) | `brew install node` |
| Plugin install (once per machine) | Provides 39 marketing skills + 51 CLIs | `/plugin marketplace add coreyhaines31/marketingskills` then `/plugin install marketing-skills@marketingskills`, then restart the session |
| Service API keys | Only for the integrations you actually use; stored in your project's `.env` | per-service |

### What you get

- **39 plugin skills** covering CRO, copy, SEO, paid, email, retention, strategy, and sales/RevOps. Claude invokes them **contextually** when you describe a task ("rewrite the homepage hero", "audit our SEO", "plan a welcome email sequence") — they don't appear in the slash menu under their `marketing-skills:<name>` namespace. The full catalog lives in the [plugin README](https://github.com/coreyhaines31/marketingskills).
- **One project-side bridge skill** — [`/marketing-context`](.claude/skills/marketing-context/SKILL.md) — that pre-populates `.agents/product-marketing-context.md` from `docs/product_spec.md`, `docs/architecture.md`, `README.md`, and sample components in `src/`, then asks only for the marketing-only gaps (personas, voice, customer language, competitors, proof points, pricing positioning). Every plugin skill reads this file before doing anything else.
- **Output destinations** — `marketing/` for collateral (`copy/`, `emails/`, `ads/`, `assets/`) and `apps/marketing/` for a marketing site if you choose to scaffold one. The site stack (Next.js / Astro / plain HTML) is deliberately deferred until first use; capture the decision in `docs/decision_log.md`.
- **Rolling notes** in [docs/marketing-strategy.md](docs/marketing-strategy.md) — same shape as `project_status.md`, marketing-focused.

### Workflow at a glance

1. Build the app first (`/new-project` → `/plan` → `/build` → `/ship`).
2. Install the plugin once per machine (see prerequisites). Restart the session so skills load.
3. Run [`/marketing-context`](.claude/skills/marketing-context/SKILL.md) to generate `.agents/product-marketing-context.md`.
4. Describe a marketing task; Claude invokes the matching plugin skill. Outputs land in `marketing/`.
5. Optional: scaffold `apps/marketing/`, build it with `/build`, review it with `/ux-review`, ship it with `/ship`.

Re-run `/marketing-context` whenever your product or positioning shifts — it's idempotent and surfaces drift section by section. Full workflow detail in [AGENTS.md §16](AGENTS.md#16-marketing-workflow).

### Customizing an upstream skill

Copy `~/.claude/plugins/cache/marketingskills/marketing-skills/<version>/skills/<name>/` into `.claude/skills/<name>/` and edit. The project version wins on the unprefixed slash form — no settings change needed (verified in Phase M1 of the [marketing restructure plan](RESTRUCTURE_MARKETING_PLAN.md)).

---

## Cross-tool compatibility

| Tool | Reads | Ignores |
|------|-------|---------|
| **Claude Code** | `CLAUDE.md` (which imports `AGENTS.md`), all of `.claude/`, `docs/standards/` | — |
| **Cursor** | `AGENTS.md`, `docs/standards/` | `.claude/`, `CLAUDE.md` overlay-only content |
| **Codex** | `AGENTS.md`, `docs/standards/` | `.claude/` |

Principles and standards live in `AGENTS.md` and `docs/standards/`. Tool-specific behavior — hooks, slash commands, skill descriptions — stays in `.claude/`. See [AGENTS.md §14](AGENTS.md#14-cross-tool-compatibility).

---

## Where to look for what

| You want to… | Look at |
|--------------|---------|
| Understand the rules every AI assistant follows | [AGENTS.md](AGENTS.md) |
| Find a workflow skill | `.claude/skills/<skill>/SKILL.md` |
| Tweak hook behavior | [.claude/hooks/](.claude/hooks/) + [.claude/settings.json](.claude/settings.json) |
| See coding/security/testing standards | [docs/standards/](docs/standards/) |
| Understand the current product | `docs/product_spec.md` |
| See current progress | `docs/project_status.md` |
| Review past decisions | `docs/decision_log.md` |
| Add a new skill | `/skill-creator` |
| Bootstrap a downstream project | `/init` (built-in) after running `/new-project` |

---

## Customizing for your project

After `/new-project`, the template is yours. Common follow-ups:

- **Add project-specific skills.** Use `/skill-creator` so they get the same eval/iterate workflow as the built-ins.
- **Add a new hook.** Drop a script in `.claude/hooks/` and wire it in `.claude/settings.json`. See the existing four for shape.
- **Fork the standards.** `docs/standards/*` are starting points — edit them as your conventions emerge. Then update `AGENTS.md` references if filenames change.
- **Disable a hook locally.** Set its event to `[]` in `.claude/settings.local.json`.

---

## License

This template is provided as-is for use as a starting point. Skills and hooks borrowed from upstream reference repos retain their original licenses where applicable.
