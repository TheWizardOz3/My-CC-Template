#!/usr/bin/env bash
# Bugsnap "start daemon" — double-click or bind to a hotkey to bring up
# Chrome (with the debug port) + the bugsnap daemon. Run once per testing session.
# Optional --url <url> passed through to the CLI.

set -e
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUGSNAP="$SCRIPT_DIR/../bin/bugsnap.js"

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

# Pass through optional --url flag; if not given, the daemon just attaches to whatever tabs exist.
RESULT=$("$NODE_BIN" "$BUGSNAP" start "$@" 2>&1) || {
  notify "Start failed — see Terminal output"
  echo "$RESULT" >&2
  exit 1
}

if echo "$RESULT" | grep -q '"alreadyRunning":true'; then
  notify "Daemon already running"
else
  notify "Daemon started"
fi
