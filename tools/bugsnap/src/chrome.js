const { spawn, execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');
const http = require('http');

const CDP_PORT = 9222;
const DEFAULT_USER_DATA_DIR = path.join(os.tmpdir(), 'bugsnap-chrome');

function findChromeBinary() {
  const candidates = process.platform === 'darwin'
    ? [
        '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
        '/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary',
        '/Applications/Chromium.app/Contents/MacOS/Chromium',
        '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
      ]
    : process.platform === 'win32'
      ? [
          'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
          'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
          'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
        ]
      : [
          '/usr/bin/google-chrome',
          '/usr/bin/google-chrome-stable',
          '/usr/bin/chromium',
          '/usr/bin/chromium-browser',
          '/snap/bin/chromium',
        ];
  for (const p of candidates) {
    if (fs.existsSync(p)) return p;
  }
  for (const cmd of ['google-chrome', 'chromium', 'chromium-browser', 'chrome']) {
    try {
      const which = process.platform === 'win32' ? 'where' : 'which';
      const found = execSync(`${which} ${cmd}`, { stdio: ['pipe', 'pipe', 'ignore'] })
        .toString().split(/\r?\n/)[0].trim();
      if (found && fs.existsSync(found)) return found;
    } catch {}
  }
  return null;
}

function isChromeDebugPortUp(port = CDP_PORT) {
  return new Promise((resolve) => {
    const req = http.get(
      { host: '127.0.0.1', port, path: '/json/version', timeout: 1000 },
      (res) => { resolve(res.statusCode === 200); res.resume(); }
    );
    req.on('error', () => resolve(false));
    req.on('timeout', () => { req.destroy(); resolve(false); });
  });
}

async function launchChrome({ url, userDataDir = DEFAULT_USER_DATA_DIR, port = CDP_PORT } = {}) {
  if (await isChromeDebugPortUp(port)) {
    return { alreadyRunning: true, port };
  }
  const binary = findChromeBinary();
  if (!binary) {
    throw new Error(
      'Chrome/Chromium not found. Install Google Chrome (https://www.google.com/chrome/) ' +
      'or set the binary path manually.'
    );
  }
  fs.mkdirSync(userDataDir, { recursive: true });
  const args = [
    `--remote-debugging-port=${port}`,
    `--user-data-dir=${userDataDir}`,
    '--no-first-run',
    '--no-default-browser-check',
    '--disable-features=ChromeWhatsNewUI',
  ];
  if (url) args.push(url);
  const child = spawn(binary, args, { detached: true, stdio: 'ignore' });
  child.unref();
  for (let i = 0; i < 50; i++) {
    if (await isChromeDebugPortUp(port)) {
      return { alreadyRunning: false, port, pid: child.pid, binary };
    }
    await new Promise(r => setTimeout(r, 200));
  }
  throw new Error('Chrome was launched but the debug port never came up. Check that no other Chrome instance is blocking the profile dir.');
}

module.exports = { findChromeBinary, isChromeDebugPortUp, launchChrome, CDP_PORT, DEFAULT_USER_DATA_DIR };
