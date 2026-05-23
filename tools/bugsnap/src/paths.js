const path = require('path');
const fs = require('fs');
const { execSync } = require('child_process');

function findProjectRoot(start = process.cwd()) {
  try {
    const out = execSync('git rev-parse --show-toplevel', {
      cwd: start,
      stdio: ['pipe', 'pipe', 'ignore'],
    }).toString().trim();
    if (out) return out;
  } catch {}
  let dir = path.resolve(start);
  while (dir !== path.dirname(dir)) {
    if (fs.existsSync(path.join(dir, '.claude'))) return dir;
    dir = path.dirname(dir);
  }
  return start;
}

function sessionsDir() {
  return path.join(findProjectRoot(), '.claude', 'bug-sessions');
}

function daemonStateFile() {
  return path.join(sessionsDir(), '.daemon.json');
}

function newSessionDir(slug) {
  const ts = new Date().toISOString().replace(/[:.]/g, '-').replace('T', '_').slice(0, 19);
  const safe = String(slug || 'snap').replace(/[^a-z0-9-]+/gi, '-').replace(/^-+|-+$/g, '').toLowerCase().slice(0, 40) || 'snap';
  const dir = path.join(sessionsDir(), `${ts}-${safe}`);
  fs.mkdirSync(path.join(dir, 'frames'), { recursive: true });
  return dir;
}

module.exports = { findProjectRoot, sessionsDir, daemonStateFile, newSessionDir };
