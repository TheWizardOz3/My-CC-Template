#!/usr/bin/env bash
# Bugsnap "capture" — bind to a global hotkey (e.g. Cmd+B).
# Prompts for a note and either marks (if a session is active) or snaps (otherwise).
# macOS only — uses osascript for prompt + notification.

set -e
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUGSNAP="$SCRIPT_DIR/../bin/bugsnap.js"

# Anchor cwd to the project that contains these scripts so bugsnap resolves
# the right .claude/bug-sessions/ regardless of launcher (Hammerspoon and
# Shortcuts.app both spawn scripts with cwd=/).
cd "$SCRIPT_DIR/../../.."

# macOS Shortcuts runs with a minimal PATH. Prepend common Node install locations.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
_nvm_latest=$(ls -1 "$HOME/.nvm/versions/node" 2>/dev/null | sort -V | tail -1)
[ -n "$_nvm_latest" ] && export PATH="$HOME/.nvm/versions/node/$_nvm_latest/bin:$PATH"

NODE_BIN="$(command -v node || true)"

notify() {
  osascript -e "display notification \"$1\" with title \"Bugsnap\"" >/dev/null 2>&1 || true
}

if [ -z "$NODE_BIN" ]; then
  notify "node not found in PATH"
  exit 1
fi

# Check daemon is up before prompting — saves the user a dialog if the answer would be useless.
STATUS_JSON=$("$NODE_BIN" "$BUGSNAP" status 2>/dev/null || echo '{"running":false}')
if ! echo "$STATUS_JSON" | grep -q '"running":[[:space:]]*true'; then
  notify "Daemon not running. Run: bugsnap start"
  exit 1
fi

# Prompt — focus the dialog so it doesn't get buried.
NOTE=$(osascript <<'APPLESCRIPT' 2>/dev/null
tell application "System Events"
  activate
  set dialogResult to display dialog "Bug note:" default answer "" with title "Bugsnap" buttons {"Cancel", "Capture"} default button "Capture" cancel button "Cancel"
  return text returned of dialogResult
end tell
APPLESCRIPT
) || exit 0

# Strip whitespace; empty note → no-op
NOTE_TRIMMED=$(echo "$NOTE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
if [ -z "$NOTE_TRIMMED" ]; then
  notify "Cancelled (empty note)"
  exit 0
fi

# Mark if session active, snap otherwise.
if echo "$STATUS_JSON" | grep -q '"activeSession":[[:space:]]*{'; then
  if "$NODE_BIN" "$BUGSNAP" mark "$NOTE_TRIMMED" >/dev/null 2>&1; then
    notify "Marked: $NOTE_TRIMMED"
  else
    notify "Mark failed"
    exit 1
  fi
else
  if "$NODE_BIN" "$BUGSNAP" snap "$NOTE_TRIMMED" >/dev/null 2>&1; then
    notify "Snapped: $NOTE_TRIMMED"
  else
    notify "Snap failed"
    exit 1
  fi
fi
