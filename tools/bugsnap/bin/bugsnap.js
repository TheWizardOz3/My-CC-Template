#!/usr/bin/env node
const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');

const { launchChrome, isChromeDebugPortUp } = require('../src/chrome');
const { readDaemonState, call } = require('../src/client');
const { sessionsDir } = require('../src/paths');

function flag(args, name) {
  const i = args.indexOf(name);
  return i === -1 ? undefined : args[i + 1];
}

async function startDaemon({ url, cdpPort = 9222, apiPort = 7654 } = {}) {
  const existing = readDaemonState();
  if (existing) {
    try {
      process.kill(existing.pid, 0);
      return { alreadyRunning: true, ...existing };
    } catch {
      // stale state, fall through
    }
  }
  if (!(await isChromeDebugPortUp(cdpPort))) {
    await launchChrome({ url, port: cdpPort });
  }
  fs.mkdirSync(sessionsDir(), { recursive: true });
  const daemonScript = path.join(__dirname, '..', 'src', 'daemon.js');
  const outLog = path.join(sessionsDir(), '.daemon.stdout.log');
  const errLog = path.join(sessionsDir(), '.daemon.stderr.log');
  const out = fs.openSync(outLog, 'a');
  const err = fs.openSync(errLog, 'a');
  const child = spawn(process.execPath, [daemonScript], {
    detached: true,
    stdio: ['ignore', out, err],
    env: { ...process.env, BUGSNAP_API_PORT: String(apiPort), BUGSNAP_CDP_PORT: String(cdpPort) },
  });
  child.unref();
  for (let i = 0; i < 50; i++) {
    const s = readDaemonState();
    if (s && s.pid) return { alreadyRunning: false, ...s };
    await new Promise((r) => setTimeout(r, 100));
  }
  throw new Error(`Daemon did not start within 5s. See ${errLog} for details.`);
}

async function stopDaemon() {
  const state = readDaemonState();
  if (!state) return { stopped: false, reason: 'not running' };
  try { await call('/shutdown'); } catch {}
  for (let i = 0; i < 40; i++) {
    if (!readDaemonState()) return { stopped: true };
    await new Promise((r) => setTimeout(r, 100));
  }
  try { process.kill(state.pid, 'SIGKILL'); } catch {}
  return { stopped: !readDaemonState() };
}

function printHelp() {
  process.stdout.write(`bugsnap — capture browser sessions for bug reports.

Usage:
  bugsnap start [--url <url>]        Launch Chrome (port 9222) + daemon.
  bugsnap stop                       Shut down the daemon.
  bugsnap status                     Show daemon state, attached tabs, active session.

  bugsnap snap "<note>"              One-shot: current screen + last 60s of events + note.
  bugsnap session start "<name>"     Begin continuous recording (auto-screenshot every click/nav).
  bugsnap mark "<note>"              Capture current screen + tag the moment (during a session).
  bugsnap session stop               End the recording session.

Sessions are written to .claude/bug-sessions/. Use the /bug-review skill to analyze them.
`);
}

async function main() {
  const args = process.argv.slice(2);
  const cmd = args[0];
  try {
    if (!cmd || ['help', '--help', '-h'].includes(cmd)) {
      printHelp();
      return;
    }
    if (cmd === 'start') {
      const url = flag(args, '--url');
      const cdpPort = parseInt(flag(args, '--cdp-port') || '9222', 10);
      const apiPort = parseInt(flag(args, '--api-port') || '7654', 10);
      const r = await startDaemon({ url, cdpPort, apiPort });
      console.log(JSON.stringify(r));
      return;
    }
    if (cmd === 'stop') {
      console.log(JSON.stringify(await stopDaemon()));
      return;
    }
    if (cmd === 'status') {
      const state = readDaemonState();
      if (!state) { console.log(JSON.stringify({ running: false })); return; }
      try {
        const s = await call('/status');
        console.log(JSON.stringify({ running: true, ...s }, null, 2));
      } catch (e) {
        console.log(JSON.stringify({ running: false, stale: true, error: e.message }));
      }
      return;
    }
    if (cmd === 'snap') {
      const note = args.slice(1).join(' ').trim();
      if (!note) { console.error('bugsnap snap requires a note. Example: bugsnap snap "submit button does nothing"'); process.exit(1); }
      console.log(JSON.stringify(await call('/snap', { note })));
      return;
    }
    if (cmd === 'mark') {
      const note = args.slice(1).join(' ').trim();
      if (!note) { console.error('bugsnap mark requires a note. Example: bugsnap mark "cart total wrong"'); process.exit(1); }
      console.log(JSON.stringify(await call('/mark', { note })));
      return;
    }
    if (cmd === 'session') {
      const sub = args[1];
      if (sub === 'start') {
        const name = args.slice(2).join(' ').trim();
        console.log(JSON.stringify(await call('/session/start', { name })));
        return;
      }
      if (sub === 'stop') {
        console.log(JSON.stringify(await call('/session/stop')));
        return;
      }
      console.error("Unknown session subcommand. Use 'session start <name>' or 'session stop'.");
      process.exit(1);
    }
    console.error(`Unknown command: ${cmd}`);
    printHelp();
    process.exit(1);
  } catch (e) {
    console.error(e.message);
    process.exit(1);
  }
}

main();
