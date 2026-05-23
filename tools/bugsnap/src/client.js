const http = require('http');
const fs = require('fs');
const { daemonStateFile } = require('./paths');

function readDaemonState() {
  try { return JSON.parse(fs.readFileSync(daemonStateFile(), 'utf8')); }
  catch { return null; }
}

function call(endpoint, payload = {}) {
  const state = readDaemonState();
  if (!state) {
    return Promise.reject(new Error("Daemon not running. Run 'bugsnap start' first."));
  }
  return new Promise((resolve, reject) => {
    const body = JSON.stringify(payload);
    const req = http.request(
      {
        host: '127.0.0.1',
        port: state.apiPort,
        path: endpoint,
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'content-length': Buffer.byteLength(body),
        },
        timeout: 10_000,
      },
      (res) => {
        let data = '';
        res.on('data', (c) => { data += c; });
        res.on('end', () => {
          try { resolve(JSON.parse(data)); }
          catch { resolve({ raw: data, status: res.statusCode }); }
        });
      }
    );
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(new Error('Daemon request timed out')); });
    req.write(body);
    req.end();
  });
}

module.exports = { readDaemonState, call };
