# bugsnap

A local sidecar that captures browser sessions — screenshots, console/network/click events, and your typed notes — into folders that the `/bug-review` Claude Code skill reads to write structured bug reports.

No video, no audio, no upload. Everything lives in `.claude/bug-sessions/` under the current project.

## Why this exists

When you click through an app and find a bug, you want to:
1. Tell the AI *what* you saw (a one-line note).
2. Show the AI *what was on the screen* (screenshot).
3. Show the AI *what the code was doing* at that moment (recent console errors, failed requests, the click that triggered it).

`bugsnap` does (2) and (3) automatically when you do (1).

## Setup (once per machine)

Requires **Node 18+** and **Google Chrome** (or Chromium / Edge).

```bash
cd tools/bugsnap
npm install
# optional, makes `bugsnap` callable from anywhere:
npm link
```

If you skip `npm link`, invoke as `node tools/bugsnap/bin/bugsnap.js …`. The `/bug-review` skill knows the path either way.

## Usage

```bash
# Launch Chrome (port 9222, isolated profile) + daemon.
bugsnap start
bugsnap start --url http://localhost:3000   # also navigates to a starting URL

# One-shot capture: current screen + last 60s of buffered events + your note.
bugsnap snap "submit button does nothing on second click"

# Continuous recording — auto-screenshots every click and navigation.
bugsnap session start "checkout-flow"
bugsnap mark "discount didn't apply"
bugsnap mark "total recalculated weirdly"
bugsnap session stop

# Inspect.
bugsnap status
bugsnap stop
```

Each capture writes a folder under `.claude/bug-sessions/<timestamp>-<slug>/`:

```
manifest.json     mode, timing, url, git sha
events.jsonl      every captured event with millisecond timestamps
marks.jsonl       your notes, each linked to a frame
frames/0001.png   screenshots
frames/index.json frame metadata (trigger, timestamp, url)
```

Then run `/bug-review` in Claude Code (this template ships the skill at `.claude/skills/bug-review/`). It reads the latest session and writes a structured report.

## Hotkey binding (macOS)

The recommended layout — two global hotkeys that work in any app:

| Hotkey | What it does |
|---|---|
| **Cmd+Option+Ctrl+B** | Prompt for a note → if a session is active, `mark`; otherwise `snap`. Same key, smart behavior. |
| **Cmd+Option+Ctrl+Shift+B** | If a session is active, stop it. Otherwise prompt for a name and start one. |

> "Hyper" combos (Cmd+Option+Ctrl) are basically never claimed by other apps — picked here so the hotkeys are global-safe across browsers, IDEs, and chat apps. Adjust if you prefer a different pair.

Two helper scripts in `scripts/` wrap the CLI with an `osascript` prompt + a macOS notification on success:

- [`scripts/capture.sh`](scripts/capture.sh) — bind to Cmd+B
- [`scripts/toggle-session.sh`](scripts/toggle-session.sh) — bind to Cmd+Shift+B
- [`scripts/start-daemon.sh`](scripts/start-daemon.sh) — double-click once per testing session to bring up Chrome + the daemon

### Bind via macOS Shortcuts (built-in, no install)

1. Open **Shortcuts.app**.
2. Click **+** to create a new shortcut. Name it `Bugsnap Capture`.
3. Add a **Run Shell Script** action. Paste:
   ```bash
   ABSOLUTE_PATH_TO/tools/bugsnap/scripts/capture.sh
   ```
   (Use the real absolute path. `Pass input: as arguments` doesn't matter — the script prompts on its own.)
4. Click the **(i)** info icon → **Add Keyboard Shortcut** → press Cmd+Option+Ctrl+B (hold all three modifiers, then tap B).
5. Check **Use as Quick Action** so it's available globally.
6. Repeat for `Bugsnap Toggle Session` → Cmd+Option+Ctrl+Shift+B → `toggle-session.sh`.

The first time the shortcut runs, macOS will ask for permission to send notifications and to use Accessibility (for the dialog). Approve both.

### Or bind via Raycast / Alfred / BetterTouchTool / Hammerspoon

All of these can run arbitrary shell scripts on a hotkey. Point them at the same script paths. Hammerspoon example:

```lua
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "B", function()
  hs.execute("/absolute/path/to/tools/bugsnap/scripts/capture.sh", true)
end)
hs.hotkey.bind({"cmd", "alt", "ctrl", "shift"}, "B", function()
  hs.execute("/absolute/path/to/tools/bugsnap/scripts/toggle-session.sh", true)
end)
```

### Linux / Windows

The CLI works everywhere; only the prompt wrapper is macOS-specific (uses `osascript`). On Linux, swap `osascript` for `zenity --entry` and bind via `xbindkeys` or your WM's config. On Windows, an AutoHotkey script with `InputBox` works the same way. The scripts under `scripts/` are short enough to adapt.

## What it captures

Per attached tab:

- **Console** — `log` / `warn` / `error` / uncaught exceptions
- **Network** — every request: URL, method, status, MIME type, errors
- **Navigation** — every top-frame URL change
- **DOM events** — clicks, form submits, inputs, change events (structure only — never input *contents*)
- **JS errors** — runtime exceptions and unhandled promise rejections

All events stamped with `Date.now()` so the skill can align them against screenshots and your notes.

## How it works

```
Chrome (port 9222) ◄──CDP──► bugsnap daemon ◄──HTTP 127.0.0.1:7654── bugsnap CLI
        ▲                          │
        │ injected script          ▼
        └──posts click/input ──► ring buffer (60s)
                                   │
                            session active?
                              yes → also writes to .claude/bug-sessions/<id>/
```

- The daemon polls Chrome every 2s for new tabs and attaches to each one.
- A tiny script is injected into every page via `Page.addScriptToEvaluateOnNewDocument` to capture DOM interactions (CDP doesn't surface clicks natively).
- Multi-tab works automatically.
- Works against any URL loaded in that Chrome instance — local dev server, staging, production — same way.

## Privacy

- Runs entirely on localhost.
- Input field *contents* are stripped from captured events. Only structure (tag, id, name, type) is kept.
- Use the isolated Chrome profile (default) to avoid mixing bugsnap with your personal browsing.

## Cross-project use

The tool is path-agnostic — it finds the project root via `git rev-parse --show-toplevel` and falls back to walking up looking for `.claude/`. Copy `tools/bugsnap/` and `.claude/skills/bug-review/` into any other project to use it there.

## Troubleshooting

- **"Daemon did not start within 5s"** — Check `.claude/bug-sessions/.daemon.stderr.log`. Usually missing deps (`npm install`) or Chrome failed to bind 9222 (another instance is running on the default profile — Chrome refuses to open with debug port if a non-debug instance already has the user-data-dir).
- **Empty `events.jsonl`** — Chrome's debug port is up but no tabs are attached. Open any tab and run `bugsnap status` to confirm.
- **Need to kill everything** — `bugsnap stop` shuts the daemon; close the isolated Chrome window separately. The temp profile lives at `/tmp/bugsnap-chrome` (macOS/Linux) and persists between runs.
