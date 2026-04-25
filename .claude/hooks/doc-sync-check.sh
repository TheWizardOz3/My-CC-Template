#!/bin/bash
# doc-sync-check.sh — Stop hook
#
# Soft reminder to update docs/changelog.md or docs/project_status.md when a
# session has touched source files but left those docs untouched. Enforces the
# AGENTS.md §11 documentation-sync mandate without nagging on every turn.
#
# Anti-nag rules (per RESTRUCTURE_PLAN.md):
#   1. Fires at most once per session (flag file keyed to session_id)
#   2. Skipped unless 3+ "source" files changed (filters docs/configs/tests)
#   3. Skipped if /plan or /end-session ran this session (those handle docs themselves)
#   4. Skipped if changelog.md or project_status.md was already touched
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

# If docs were touched, we are good
if echo "$CHANGED" | grep -qE '(^|/)(changelog|project_status)\.md$'; then
  touch "$FLAG"
  exit 0
fi

# Count source file changes (exclude docs, configs, tests, lockfiles, .claude)
SOURCE_FILES=$(echo "$CHANGED" \
  | grep -vE '(^|/)\.DS_Store$|\.md$|^\.claude/|^docs/|^README|(^|/)package(-lock)?\.json$|(^|/)pnpm-lock\.yaml$|(^|/)yarn\.lock$|(^|/)bun\.lockb$|(^|/)\.gitignore$|\.test\.|\.spec\.|(^|/)__tests__/|(^|/)tests?/' \
  | grep -cv '^[[:space:]]*$')

# Threshold: 3+ source files
[[ "$SOURCE_FILES" -lt 3 ]] && exit 0

# Skip if /plan or /end-session ran this session (they own their doc updates)
if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
  if grep -qE '"/(plan|end-session)([[:space:]"]|\\)' "$TRANSCRIPT_PATH" 2>/dev/null; then
    touch "$FLAG"
    exit 0
  fi
fi

touch "$FLAG"

cat >&2 <<EOF
DOC SYNC REMINDER: ${SOURCE_FILES} source files changed this session, but neither docs/changelog.md nor docs/project_status.md was updated.

Per AGENTS.md §11, before ending the session:
  - If a feature shipped: invoke /ship (delegates to doc-updater agent)
  - If mid-flight: add a 1-2 line entry to docs/changelog.md and update docs/project_status.md
  - If decisions were made: append to docs/decision_log.md

This reminder fires once per session.
EOF

exit 2
