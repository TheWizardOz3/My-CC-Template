#!/usr/bin/env bash
# Bugsnap "toggle session" — bind to a global hotkey (e.g. Cmd+Shift+B).
# If a session is active, stops it. Otherwise prompts for a name and starts one.
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

STATUS_JSON=$("$NODE_BIN" "$BUGSNAP" status 2>/dev/null || echo '{"running":false}')
if ! echo "$STATUS_JSON" | grep -q '"running":[[:space:]]*true'; then
  notify "Daemon not running. Run: bugsnap start"
  exit 1
fi

if echo "$STATUS_JSON" | grep -q '"activeSession":[[:space:]]*{'; then
  # Active session — stop it.
  if "$NODE_BIN" "$BUGSNAP" session stop >/dev/null 2>&1; then
    notify "Session stopped"
  else
    notify "Stop failed"
    exit 1
  fi
else
  # No active session — prompt for name, then start.
  NAME=$(osascript <<'APPLESCRIPT' 2>/dev/null
tell application "System Events"
  activate
  set dialogResult to display dialog "Session name:" default answer "" with title "Bugsnap — start session" buttons {"Cancel", "Start"} default button "Start" cancel button "Cancel"
  return text returned of dialogResult
end tell
APPLESCRIPT
  ) || exit 0

  NAME_TRIMMED=$(echo "$NAME" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  if [ -z "$NAME_TRIMMED" ]; then
    NAME_TRIMMED="session"
  fi

  if "$NODE_BIN" "$BUGSNAP" session start "$NAME_TRIMMED" >/dev/null 2>&1; then
    notify "Session started: $NAME_TRIMMED"
  else
    notify "Start failed"
    exit 1
  fi
fi
