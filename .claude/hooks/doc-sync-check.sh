#!/bin/bash
# doc-sync-check.sh — Stop hook
#
# Soft reminder to update doc-of-record files when a session has touched source
# or marketing files but left those docs untouched. Enforces the AGENTS.md §11
# documentation-sync mandate without nagging on every turn.
#
# Two independent checks (either can fire; combined into one reminder):
#   - Dev: 3+ source files changed but neither docs/changelog.md nor
#     docs/project_status.md was touched.
#   - Marketing: 1+ files under marketing/ or apps/marketing/ changed but
#     docs/marketing-strategy.md was not touched.
#
# Anti-nag rules:
#   1. Fires at most once per session (flag file keyed to session_id)
#   2. Source-side filters out docs/configs/tests/lockfiles/.claude
#   3. Skipped if /plan or /end-session ran this session (they own their docs)
#   4. Skipped if the relevant doc-of-record was already touched
#   5. Respects stop_hook_active to avoid Stop-hook loops
#
# Exit codes:
#   0 = silent allow (no reminder needed)
#   2 = block stop + feed stderr back to Claude as a reminder

set -u

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')

# Loop guard
[[ "$STOP_HOOK_ACTIVE" == "true" ]] && exit 0
[[ -z "$SESSION_ID" ]] && exit 0

FLAG="/tmp/claude-doc-sync-fired-${SESSION_ID}"
[[ -f "$FLAG" ]] && exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" 2>/dev/null || exit 0

# Need a git repo to inspect
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# All changed files (modified + staged + individual untracked files).
# Avoid `git status --porcelain` because it collapses untracked dirs to "dir/"
# instead of listing files inside.
CHANGED=$(
  {
    git diff --name-only HEAD 2>/dev/null
    git diff --name-only --cached 2>/dev/null
    git ls-files --others --exclude-standard 2>/dev/null
  } | sort -u
)
[[ -z "$CHANGED" ]] && exit 0

# --- Dev-side check ----------------------------------------------------------
# Doc-of-record touched? (changelog.md or project_status.md)
DEV_DOCS_TOUCHED=0
if echo "$CHANGED" | grep -qE '(^|/)(changelog|project_status)\.md$'; then
  DEV_DOCS_TOUCHED=1
fi

# Source files changed (exclude docs, configs, tests, lockfiles, .claude, marketing)
SOURCE_FILES=$(echo "$CHANGED" \
  | grep -vE '(^|/)\.DS_Store$|\.md$|^\.claude/|^docs/|^README|^marketing/|^apps/marketing/|(^|/)package(-lock)?\.json$|(^|/)pnpm-lock\.yaml$|(^|/)yarn\.lock$|(^|/)bun\.lockb$|(^|/)\.gitignore$|\.test\.|\.spec\.|(^|/)__tests__/|(^|/)tests?/' \
  | grep -cv '^[[:space:]]*$')

DEV_REMINDER_NEEDED=0
if [[ "$DEV_DOCS_TOUCHED" -eq 0 && "$SOURCE_FILES" -ge 3 ]]; then
  DEV_REMINDER_NEEDED=1
fi

# --- Marketing-side check ----------------------------------------------------
# Doc-of-record touched? (marketing-strategy.md)
MARKETING_DOC_TOUCHED=0
if echo "$CHANGED" | grep -qE '(^|/)marketing-strategy\.md$'; then
  MARKETING_DOC_TOUCHED=1
fi

# Marketing artifact files changed (anything under marketing/ or apps/marketing/)
MARKETING_FILES=$(echo "$CHANGED" \
  | grep -E '^marketing/|^apps/marketing/' \
  | grep -vE '(^|/)README\.md$|(^|/)\.gitkeep$' \
  | grep -cv '^[[:space:]]*$')

MARKETING_REMINDER_NEEDED=0
if [[ "$MARKETING_DOC_TOUCHED" -eq 0 && "$MARKETING_FILES" -ge 1 ]]; then
  MARKETING_REMINDER_NEEDED=1
fi

# --- Combine + emit ----------------------------------------------------------
if [[ "$DEV_REMINDER_NEEDED" -eq 0 && "$MARKETING_REMINDER_NEEDED" -eq 0 ]]; then
  touch "$FLAG"
  exit 0
fi

# Skip if /plan or /end-session ran this session (they own their doc updates)
if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
  if grep -qE '"/(plan|end-session)([[:space:]"]|\\)' "$TRANSCRIPT_PATH" 2>/dev/null; then
    touch "$FLAG"
    exit 0
  fi
fi

touch "$FLAG"

{
  echo "DOC SYNC REMINDER:"
  if [[ "$DEV_REMINDER_NEEDED" -eq 1 ]]; then
    echo "  - ${SOURCE_FILES} source files changed, but neither docs/changelog.md nor docs/project_status.md was updated."
  fi
  if [[ "$MARKETING_REMINDER_NEEDED" -eq 1 ]]; then
    echo "  - ${MARKETING_FILES} marketing file(s) changed under marketing/ or apps/marketing/, but docs/marketing-strategy.md was not updated."
  fi
  echo
  echo "Per AGENTS.md §11, before ending the session:"
  if [[ "$DEV_REMINDER_NEEDED" -eq 1 ]]; then
    echo "  - If a feature shipped: invoke /ship (delegates to doc-updater agent)"
    echo "  - If mid-flight: add a 1-2 line entry to docs/changelog.md and update docs/project_status.md"
    echo "  - If decisions were made: append to docs/decision_log.md"
  fi
  if [[ "$MARKETING_REMINDER_NEEDED" -eq 1 ]]; then
    echo "  - For marketing: update docs/marketing-strategy.md (move/add an entry; same brevity rules as project_status.md)"
  fi
  echo
  echo "This reminder fires once per session."
} >&2

exit 2
