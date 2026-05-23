const http = require('http');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const { TargetWatcher, listTargets } = require('./cdp');
const { sessionsDir, daemonStateFile, newSessionDir } = require('./paths');

const BUFFER_WINDOW_MS = 60_000;
const POLL_INTERVAL_MS = 2000;
const CDP_FAILURE_THRESHOLD = 3; // ~6s of unreachable CDP port → Chrome quit (Cmd+Q)
const NO_TARGETS_THRESHOLD = 5;  // ~10s of zero page targets → last window closed (Cmd+W)

function gitSha() {
  try {
    return execSync('git rev-parse HEAD', { stdio: ['pipe', 'pipe', 'ignore'] })
      .toString().trim();
  } catch { return null; }
}

class Daemon {
  constructor({ cdpPort = 9222, apiPort = 7654 } = {}) {
    this.cdpPort = cdpPort;
    this.apiPort = apiPort;
    this.watchers = new Map();
    this.buffer = [];
    this.activeSession = null;
    this.logFile = path.join(sessionsDir(), '.daemon.log');
    this.everAttached = false;
    this.consecutiveCdpFailures = 0;
    this.everHadPageTarget = false;
    this.consecutivePollsWithNoTargets = 0;
  }

  log(msg) {
    try { fs.appendFileSync(this.logFile, `[${new Date().toISOString()}] ${msg}\n`); } catch {}
  }

  onEvent(ev) {
    this.buffer.push(ev);
    const cutoff = Date.now() - BUFFER_WINDOW_MS;
    while (this.buffer.length && this.buffer[0].ts < cutoff) this.buffer.shift();

    if (this.activeSession) {
      this.activeSession.eventsStream.write(JSON.stringify(ev) + '\n');
      if (ev.type === 'page.click' || ev.type === 'nav') {
        this.captureFrame(ev.targetId, ev.type === 'nav' ? 'nav' : 'click').catch(() => {});
      }
    }
  }

  async pollTargets() {
    let list;
    try {
      list = await listTargets(this.cdpPort);
      this.consecutiveCdpFailures = 0;
      this.everAttached = true;
    } catch {
      this.consecutiveCdpFailures++;
      if (this.everAttached && this.consecutiveCdpFailures >= CDP_FAILURE_THRESHOLD) {
        this.log(`Chrome unreachable for ${this.consecutiveCdpFailures} polls — shutting down`);
        process.kill(process.pid, 'SIGTERM');
      }
      return;
    }
    const pageTargets = list.filter((t) => t.type === 'page');
    if (pageTargets.length > 0) {
      this.everHadPageTarget = true;
      this.consecutivePollsWithNoTargets = 0;
    } else if (this.everHadPageTarget) {
      this.consecutivePollsWithNoTargets++;
      if (this.consecutivePollsWithNoTargets >= NO_TARGETS_THRESHOLD) {
        this.log(`No Chrome page targets for ${this.consecutivePollsWithNoTargets} polls — shutting down`);
        process.kill(process.pid, 'SIGTERM');
        return;
      }
    }
    const seen = new Set();
    for (const t of pageTargets) {
      seen.add(t.id);
      if (!this.watchers.has(t.id)) {
        const w = new TargetWatcher(t, (ev) => this.onEvent(ev));
        const ok = await w.attach();
        if (ok) {
          this.watchers.set(t.id, w);
          this.log(`Attached to ${t.url}`);
        }
      } else {
        this.watchers.get(t.id).targetInfo.url = t.url;
        this.watchers.get(t.id).lastUrl = t.url;
      }
    }
    for (const [id, w] of this.watchers) {
      if (!seen.has(id)) {
        await w.detach();
        this.watchers.delete(id);
        this.log(`Detached ${id}`);
      }
    }
  }

  mostActiveWatcher() {
    for (let i = this.buffer.length - 1; i >= 0; i--) {
      const w = this.watchers.get(this.buffer[i].targetId);
      if (w) return w;
    }
    return [...this.watchers.values()][0] || null;
  }

  async captureFrame(targetId, trigger) {
    if (!this.activeSession) return null;
    const watcher = (targetId && this.watchers.get(targetId)) || this.mostActiveWatcher();
    if (!watcher) return null;
    const buf = await watcher.screenshot();
    if (!buf) return null;
    const seq = String(++this.activeSession.sequence).padStart(4, '0');
    const filename = `${seq}.png`;
    fs.writeFileSync(path.join(this.activeSession.dir, 'frames', filename), buf);
    const entry = {
      file: filename,
      ts: Date.now(),
      trigger,
      url: watcher.lastUrl,
    };
    this.activeSession.frameIndex.push(entry);
    fs.writeFileSync(
      path.join(this.activeSession.dir, 'frames', 'index.json'),
      JSON.stringify(this.activeSession.frameIndex, null, 2)
    );
    return entry;
  }

  async snap(note) {
    const dir = newSessionDir((note || 'snap').split(/\s+/).slice(0, 4).join('-'));
    const watcher = this.mostActiveWatcher();
    let frame = null;
    if (watcher) {
      const buf = await watcher.screenshot();
      if (buf) {
        fs.writeFileSync(path.join(dir, 'frames', '0001.png'), buf);
        frame = { file: '0001.png', ts: Date.now(), trigger: 'snap', url: watcher.lastUrl };
      }
    }
    fs.writeFileSync(
      path.join(dir, 'frames', 'index.json'),
      JSON.stringify(frame ? [frame] : [], null, 2)
    );
    const events = this.buffer.slice();
    fs.writeFileSync(
      path.join(dir, 'events.jsonl'),
      events.map((e) => JSON.stringify(e)).join('\n') + (events.length ? '\n' : '')
    );
    fs.writeFileSync(
      path.join(dir, 'marks.jsonl'),
      JSON.stringify({ ts: Date.now(), note: note || '', frame: frame && frame.file }) + '\n'
    );
    fs.writeFileSync(
      path.join(dir, 'manifest.json'),
      JSON.stringify({
        mode: 'snap',
        note: note || '',
        createdAt: new Date().toISOString(),
        url: watcher ? watcher.lastUrl : null,
        gitSha: gitSha(),
        bufferWindowMs: BUFFER_WINDOW_MS,
        eventCount: events.length,
        attachedTargets: [...this.watchers.values()].map((w) => w.lastUrl),
      }, null, 2)
    );
    this.log(`Snap → ${dir}`);
    return { dir, eventCount: events.length, frame: frame && frame.file };
  }

  startSession(name) {
    if (this.activeSession) {
      return { error: 'session already active', dir: this.activeSession.dir };
    }
    const dir = newSessionDir(name || 'session');
    const eventsStream = fs.createWriteStream(path.join(dir, 'events.jsonl'), { flags: 'a' });
    const marksStream = fs.createWriteStream(path.join(dir, 'marks.jsonl'), { flags: 'a' });
    this.activeSession = {
      dir,
      name: name || '',
      eventsStream,
      marksStream,
      frameIndex: [],
      sequence: 0,
      startedAt: Date.now(),
    };
    fs.writeFileSync(
      path.join(dir, 'manifest.json'),
      JSON.stringify({
        mode: 'session',
        name: name || '',
        createdAt: new Date().toISOString(),
        gitSha: gitSha(),
        attachedTargets: [...this.watchers.values()].map((w) => w.lastUrl),
      }, null, 2)
    );
    for (const ev of this.buffer) eventsStream.write(JSON.stringify(ev) + '\n');
    this.log(`Session started: ${dir}`);
    return { dir };
  }

  async mark(note) {
    if (!this.activeSession) return { error: 'no active session' };
    const frame = await this.captureFrame(null, 'mark');
    const entry = { ts: Date.now(), note: note || '', frame: frame && frame.file };
    this.activeSession.marksStream.write(JSON.stringify(entry) + '\n');
    this.log(`Mark: ${note || ''}`);
    return { mark: entry };
  }

  stopSession() {
    if (!this.activeSession) return { error: 'no active session' };
    const { dir, eventsStream, marksStream, sequence, startedAt } = this.activeSession;
    try { eventsStream.end(); } catch {}
    try { marksStream.end(); } catch {}
    try {
      const manifestPath = path.join(dir, 'manifest.json');
      const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
      manifest.endedAt = new Date().toISOString();
      manifest.frameCount = sequence;
      manifest.durationMs = Date.now() - startedAt;
      fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
    } catch (e) { this.log(`Manifest finalize failed: ${e.message}`); }
    this.activeSession = null;
    this.log(`Session stopped: ${dir}`);
    return { dir };
  }

  status() {
    return {
      cdpPort: this.cdpPort,
      apiPort: this.apiPort,
      attachedTargets: [...this.watchers.values()].map((w) => w.lastUrl),
      bufferSize: this.buffer.length,
      activeSession: this.activeSession
        ? {
            dir: this.activeSession.dir,
            name: this.activeSession.name,
            frames: this.activeSession.sequence,
            startedAt: new Date(this.activeSession.startedAt).toISOString(),
          }
        : null,
    };
  }

  async start() {
    fs.mkdirSync(sessionsDir(), { recursive: true });
    this.log('Daemon starting');
    await this.pollTargets();
    this.pollInterval = setInterval(() => this.pollTargets().catch(() => {}), POLL_INTERVAL_MS);
    this.server = http.createServer((req, res) => this.handle(req, res));
    await new Promise((resolve, reject) => {
      this.server.once('error', reject);
      this.server.listen(this.apiPort, '127.0.0.1', resolve);
    });
    fs.writeFileSync(
      daemonStateFile(),
      JSON.stringify({
        pid: process.pid,
        apiPort: this.apiPort,
        cdpPort: this.cdpPort,
        startedAt: new Date().toISOString(),
      })
    );
    this.log(`Listening on 127.0.0.1:${this.apiPort}`);

    const shutdown = async () => {
      this.log('Shutting down');
      try { clearInterval(this.pollInterval); } catch {}
      try { if (this.activeSession) this.stopSession(); } catch {}
      for (const w of this.watchers.values()) {
        try { await w.detach(); } catch {}
      }
      try { fs.unlinkSync(daemonStateFile()); } catch {}
      try { this.server.close(); } catch {}
      process.exit(0);
    };
    process.on('SIGINT', shutdown);
    process.on('SIGTERM', shutdown);
  }

  async handle(req, res) {
    if (req.method !== 'POST' && req.url !== '/status') {
      res.writeHead(405); res.end(); return;
    }
    let body = '';
    req.on('data', (c) => { body += c; if (body.length > 1e6) req.destroy(); });
    req.on('end', async () => {
      try {
        const data = body ? JSON.parse(body) : {};
        let result;
        switch (req.url) {
          case '/status': result = this.status(); break;
          case '/snap': result = await this.snap(data.note); break;
          case '/session/start': result = this.startSession(data.name); break;
          case '/session/stop': result = this.stopSession(); break;
          case '/mark': result = await this.mark(data.note); break;
          case '/shutdown':
            result = { ok: true };
            setTimeout(() => process.kill(process.pid, 'SIGTERM'), 50);
            break;
          default:
            res.writeHead(404); res.end(); return;
        }
        res.writeHead(200, { 'content-type': 'application/json' });
        res.end(JSON.stringify(result));
      } catch (e) {
        this.log(`Handler error: ${e.message}`);
        res.writeHead(500, { 'content-type': 'application/json' });
        res.end(JSON.stringify({ error: e.message }));
      }
    });
  }
}

if (require.main === module) {
  const apiPort = parseInt(process.env.BUGSNAP_API_PORT || '7654', 10);
  const cdpPort = parseInt(process.env.BUGSNAP_CDP_PORT || '9222', 10);
  new Daemon({ apiPort, cdpPort }).start().catch((e) => {
    console.error('Daemon failed to start:', e.message);
    process.exit(1);
  });
}

module.exports = Daemon;
