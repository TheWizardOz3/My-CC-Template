---
name: bug-review
description: "Capture and analyze browser bug sessions. Two modes: (1) start a capture session — launches Chrome + the bugsnap daemon and hands the user the commands to run while clicking through the app; (2) review a captured session — reads the screenshots, event logs, and user notes from .claude/bug-sessions/, correlates them with the codebase, and writes a structured bug report. Triggers on 'bug review', 'start a bug session', 'capture a bug', 'review the bug session', '/bug-review', or when the user wants to narrate bugs while testing and have Claude analyze them after. Do NOT use for /ux-review (that's self-driven exploratory UI evaluation) or /debug (that's a root-cause methodology for a known reproducible bug)."
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep, Write
---

# Bug Review

Two modes, decided from the user's input:

| User said… | Mode |
|---|---|
| "start a bug session", "I want to capture some bugs", "set up bug review" | **Start** |
| "review the session", "/bug-review &lt;id&gt;", "analyze the captured bugs", "what did I find" | **Review** |
| just "/bug-review" with no prior session active and no folder named | ask which they want |

Run `node tools/bugsnap/bin/bugsnap.js status` first if uncertain — if a daemon is running and an active session is in progress, the user almost certainly wants Review (after stopping it) or Mark (during it). If nothing is running, they want Start.

---

## Start mode

### 1. Ensure the sidecar is ready

```bash
test -d tools/bugsnap && test -f tools/bugsnap/bin/bugsnap.js || echo MISSING
```

If `MISSING`: stop and tell the user the `bugsnap` sidecar isn't in this project. Point at `.claude/skills/bug-review/` and `tools/bugsnap/` in the template repo. Don't try to recreate it from scratch.

Check deps:

```bash
test -d tools/bugsnap/node_modules || (cd tools/bugsnap && npm install)
```

Run the install if needed — first-time setup in a fresh clone always hits this.

### 2. Figure out the app URL

Don't ask if you can avoid it. Look in this order and use the first hit:

1. `docs/architecture.md` — search for "local dev", "localhost", or a URL in the dev section
2. `package.json` `scripts.dev` or `scripts.start` — infer port from framework:
   - `vite` → `http://localhost:5173`
   - `next dev` → `http://localhost:3000`
   - `react-scripts start` → `http://localhost:3000`
   - `astro dev` → `http://localhost:4321`
   - `nuxt dev` → `http://localhost:3000`
   - `sveltekit` / `vite dev` → `http://localhost:5173`
3. `.env*` for a `PORT=` or `VITE_PORT=` line
4. If user said "testing prod" or gave a URL, use that

Only ask if all four come up empty. Show the user what you picked before launching.

### 3. Start

```bash
node tools/bugsnap/bin/bugsnap.js start --url <url>
```

This launches Chrome with `--remote-debugging-port=9222` in an isolated profile (`/tmp/bugsnap-chrome`), then spawns the daemon detached. Both survive when this turn ends. Confirm the JSON output shows a `pid`.

If the user wants to start recording immediately (so every click from the start is captured):

```bash
node tools/bugsnap/bin/bugsnap.js session start "<short-name>"
```

Default to **not** auto-starting a session — most users want to poke around first and only `snap` when something goes wrong. Mention the option in your handoff.

### 4. Hand off

Hand the user — compactly — their options. Prefer the hotkey path; surface the CLI fallback. Adjust the binary prefix based on whether they ran `npm link`:

```
Capture while you test:

  Cmd+Option+Ctrl+B          Prompt for note → snap (or mark, if a session is active).
  Cmd+Option+Ctrl+Shift+B    Toggle session (prompt for name on start).

Hotkeys not bound yet? Two options:
  (a) Bind the scripts in tools/bugsnap/scripts/ — ~30s via macOS Shortcuts.app.
      Instructions: tools/bugsnap/README.md § "Hotkey binding (macOS)".
  (b) Skip hotkeys and use the CLI:
        bugsnap snap "<note>"            One-shot capture.
        bugsnap session start "<name>"   Begin continuous recording.
        bugsnap mark "<note>"            Mark a moment during a session.
        bugsnap session stop             End the session.
        bugsnap status / bugsnap stop    Inspect / shut down.

When you've finished, say "review the session" and I'll write up the bugs.
```

If they didn't `npm link`, replace `bugsnap` with `node tools/bugsnap/bin/bugsnap.js`.

End your turn there. The user goes off and does their thing.

---

## Review mode

### 1. Locate the session

```bash
ls -t .claude/bug-sessions/ | grep -v '^\.' | head -5
```

- `/bug-review` with no arg → most recent folder.
- `/bug-review <id>` or "the foo session" → match by prefix; ask if ambiguous.

Show the user which session you're reviewing before going further.

If a daemon is still running and a session is still active, run `bugsnap session stop` first — incomplete sessions can be read but the manifest won't have `endedAt`/`frameCount` finalized.

### 2. Load the data

For the chosen folder, read:

- `manifest.json` — mode, timing, git sha, urls
- `marks.jsonl` — one JSON object per line, each is a user-tagged moment
- `frames/index.json` — frame metadata
- `events.jsonl` — line-delimited events (can be large; read once, parse in memory)

Skim `events.jsonl` for any `jserror`, `exception`, `unhandledrejection`, `network.failed`, or `network.response` with status ≥ 400 — these are auto-flagged regardless of whether the user marked them.

Read frame PNGs only when you're about to discuss a specific moment. Use the Read tool on the PNG path.

### 3. Walk the timeline

Order: every user mark, chronologically. Plus any auto-flagged errors that the user didn't mark (lower priority section).

For each moment:

1. **Frame** — Read the linked PNG. One sentence on what's visibly happening.
2. **User's note** — verbatim from `marks.jsonl`.
3. **Event window** — slice `events.jsonl` from `mark.ts - 10000` to `mark.ts + 2000`. Look for:
   - `exception` / `jserror` / `unhandledrejection` — highest priority. The `filename` + line/col point at code if source maps resolved.
   - `network.failed` events — `errorText` plus the failed `url`
   - `network.response` with `status >= 400` — note the URL and status
   - The `page.click` event immediately preceding the mark — what was clicked (tag, id, testId, text)
   - Recent `console` errors/warns
4. **Code link-back** — for each interesting event:
   - If the event has a real `filename` URL, try to map it: strip the host, see if the path matches a file in `src/`. Grep for the basename if not.
   - For clicks: grep the repo for the `testId`, `id`, or `aria-label` from the event. If `text` is short and distinctive, grep for that string in JSX/TSX/HTML.
   - For network failures: grep for the failing URL path (e.g., `/api/foo/bar`) — usually finds the fetch call.
   - Use the Grep tool. Prefer `src/`, `app/`, `pages/`, `components/` over the whole tree.

### 4. Write the report

Render directly in chat. Don't write a file unless the user asks. Format per issue:

```
### <Short title — what's broken>

**Frame** `<filename>` @ <human time, e.g., 14:32:07>: <one-line scene description>
**User said**: "<note>"
**Signals**:
- <key event 1, e.g., "TypeError: Cannot read 'map' of undefined at ProductList.tsx:42">
- <key event 2, e.g., "POST /api/cart returned 500">
**Likely cause**: <hypothesis in one line>
**Suspect code**:
- [`src/components/ProductList.tsx:42`](src/components/ProductList.tsx#L42) — <why>
**Suggested fix**: <one-liner if obvious, or "needs investigation: <what to check>">
```

Rules:
- Group multiple marks into one issue if they're the same bug from different angles. Cross-reference frames inline.
- Order: exceptions / failed requests first; broken UX (wrong content, missing element) next; cosmetic last.
- If a mark has no surrounding errors and no clear click, label it **Observation, not bug** and one-line it.
- After the per-issue list, write a 2-line **Summary** of what's most worth fixing.

### 5. Offer next steps

```
Want me to:
  (a) open the suspect files for one of these
  (b) write a fix for <issue N>
  (c) save this report to docs/bug-reports/<session-id>.md
  (d) leave it as-is — you'll triage from here
```

Do NOT auto-fix. The user narrated bugs; they may want to look at the report before diving in.

---

## Notes on robustness

- **No source maps in prod** — `filename` URLs from a prod build point to bundled JS, not source files. Grep by URL path, component name visible in clicks, or testId instead. Don't fabricate file paths.
- **Empty events** — if `events.jsonl` is empty or near-empty, the daemon attached but no interaction happened. Tell the user; ask if they ran `bugsnap status` to confirm attachment during the session.
- **Massive events.jsonl** — if events file is &gt; 5 MB, only load full content for windows around marks; for the overview pass, just scan for `jserror|exception|unhandledrejection|"status":[45]` matches.
- **Multiple sessions captured together** — if marks span more time than one logical bug, group by clusters of marks separated by &gt;5 min gaps.

## Don't

- Don't run `bugsnap stop` without confirming. The daemon may be intentionally kept alive across multiple review passes.
- Don't delete sessions. They're cheap to keep, expensive to recapture.
- Don't write the bug report to disk by default. Chat output unless asked.
- Don't claim a file is "broken" without showing the code or the linked stack frame.
