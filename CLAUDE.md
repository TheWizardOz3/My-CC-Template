# CLAUDE.md

Claude Code-specific overlay. The universal rulebook lives in [AGENTS.md](AGENTS.md) and is imported below.

@AGENTS.md

## Claude Code specifics

- **Hooks** are wired in [.claude/settings.json](.claude/settings.json) (safety guard, session start, notification, doc-sync check). See [.claude/hooks/README.md](.claude/hooks/README.md) for what each hook does and its dependencies.
- **Personal overrides** go in `.claude/settings.local.json` (gitignored). Copy [.claude/settings.local.json.example](.claude/settings.local.json.example) as a starting point.
- **Skills** live in [.claude/skills/](.claude/skills/) — eleven user- and model-invocable workflows. See [README.md](README.md) for the full list.
- **Agents** live in [.claude/agents/](.claude/agents/) — currently just [`doc-updater`](.claude/agents/doc-updater.md). Built-in `feature-dev:*` and `Explore` agents handle the rest.
- **Templates** live alongside the skills that use them (e.g. `.claude/skills/plan/references/feature-template.md`). Cursor and Codex use `AGENTS.md` directly and ignore this overlay.

> Onboarding a fresh clone? Run `/new-project` to fill in `docs/*` and `AGENTS.md` placeholders. See [README.md](README.md) for setup and dependencies.
