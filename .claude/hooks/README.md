# Claude Code Hooks

Project-local hooks wired in [.claude/settings.json](../settings.json). Each runs in its own shell, scoped to `$CLAUDE_PROJECT_DIR` so they work in any clone of this template.

## Hooks

| Script | Event | Purpose |
|--------|-------|---------|
| `safety-guard.sh` | `PreToolUse` (Bash, WebFetch) | Blocks destructive commands (`rm`, `sudo`, force-push, broad `git add`, system-dir writes, `curl ... \| sh`, `.env` overwrites) and refuses to send commands containing literal API keys/secrets. Mirrors AGENTS.md §3. Borrowed verbatim from the `jules` repo. |
| `session-start.sh` | `SessionStart` | Runs `git pull --ff-only` so a new session doesn't start on a stale branch. Silent on failure (e.g. detached HEAD). |
| `notify-input.sh` | `Notification` | macOS notification (or OSC 9 escape on Linux/containers) when Claude is awaiting input and the terminal is not in the foreground. |
| `doc-sync-check.sh` | `Stop` | Soft reminder to update doc-of-record files. Two checks: (a) 3+ source files changed but neither `docs/changelog.md` nor `docs/project_status.md` was touched; (b) 1+ files under `marketing/` or `apps/marketing/` changed but `docs/marketing-strategy.md` was not. Anti-nag: fires at most once per session, combined into a single message, and skipped if `/plan` or `/end-session` ran. |

## Dependencies

| Tool | Used by | Required? | Install |
|------|---------|-----------|---------|
| `bash` | all hooks | yes | preinstalled |
| `jq` | `safety-guard.sh`, `doc-sync-check.sh` | **yes — hooks fail closed without it** | `brew install jq` (macOS), `apt install jq` (Linux) |
| `osascript` | `notify-input.sh` | macOS only (falls back to OSC 9 elsewhere) | preinstalled on macOS |
| `git` | `session-start.sh`, `doc-sync-check.sh` | yes | preinstalled |

> ⚠️ Without `jq`, the `PreToolUse` safety guard will error and Claude Code will block every Bash/WebFetch call. Install it before relying on this template.

## Disabling a hook

Per-developer overrides go in `.claude/settings.local.json` (gitignored — copy the example from the project root). To turn a hook off for yourself without touching shared settings, set its event to an empty array:

```json
{
  "hooks": {
    "Notification": []
  }
}
```

## Editing hooks

The three hooks copied from `jules` are kept verbatim so improvements upstream can be re-pulled. Project-specific changes belong in `doc-sync-check.sh` or in a new hook file.
