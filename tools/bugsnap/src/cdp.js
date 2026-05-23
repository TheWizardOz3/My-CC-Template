const CDP = require('chrome-remote-interface');
const INJECT_SCRIPT = require('./inject');

const MAGIC = '__BUGSNAP__';

class TargetWatcher {
  constructor(targetInfo, onEvent) {
    this.targetInfo = targetInfo;
    this.onEvent = onEvent;
    this.client = null;
    this.attached = false;
    this.lastUrl = targetInfo.url;
  }

  async attach() {
    try {
      this.client = await CDP({ target: this.targetInfo.webSocketDebuggerUrl });
      const { Network, Page, Runtime } = this.client;
      await Promise.all([Network.enable(), Page.enable(), Runtime.enable()]);
      await Page.addScriptToEvaluateOnNewDocument({ source: INJECT_SCRIPT });
      try { await Runtime.evaluate({ expression: INJECT_SCRIPT }); } catch {}

      Network.requestWillBeSent(({ requestId, request, type }) => {
        this.emit('network.request', { requestId, url: request.url, method: request.method, type });
      });
      Network.responseReceived(({ requestId, response, type }) => {
        this.emit('network.response', {
          requestId,
          url: response.url,
          status: response.status,
          type,
          mimeType: response.mimeType,
        });
      });
      Network.loadingFailed(({ requestId, errorText, canceled, type }) => {
        this.emit('network.failed', { requestId, errorText, canceled, type });
      });
      Page.frameNavigated(({ frame }) => {
        if (frame.parentId) return;
        this.lastUrl = frame.url;
        this.targetInfo.url = frame.url;
        this.emit('nav', { url: frame.url });
      });
      Runtime.consoleAPICalled((params) => {
        const args = params.args || [];
        const first = args[0] && args[0].value;
        if (first === MAGIC && args[1] && typeof args[1].value === 'string') {
          try {
            const payload = JSON.parse(args[1].value);
            this.emit('page.' + payload.type, payload.data);
            return;
          } catch {}
        }
        const text = args
          .map((a) => (a.value !== undefined ? String(a.value) : a.description || ''))
          .join(' ')
          .slice(0, 500);
        this.emit('console', { level: params.type, text });
      });
      Runtime.exceptionThrown(({ exceptionDetails }) => {
        this.emit('exception', {
          text: exceptionDetails.text,
          url: exceptionDetails.url,
          line: exceptionDetails.lineNumber,
          col: exceptionDetails.columnNumber,
          stack:
            exceptionDetails.stackTrace &&
            exceptionDetails.stackTrace.callFrames.slice(0, 10).map((f) => ({
              fn: f.functionName,
              url: f.url,
              line: f.lineNumber,
              col: f.columnNumber,
            })),
        });
      });
      this.client.on('disconnect', () => {
        this.attached = false;
      });
      this.attached = true;
      return true;
    } catch {
      this.attached = false;
      return false;
    }
  }

  emit(type, data) {
    this.onEvent({
      ts: Date.now(),
      type,
      data,
      url: this.lastUrl,
      targetId: this.targetInfo.id,
    });
  }

  async screenshot() {
    if (!this.client) return null;
    try {
      const { Page } = this.client;
      try { await Page.bringToFront(); } catch {}
      const { data } = await Page.captureScreenshot({ format: 'png' });
      return Buffer.from(data, 'base64');
    } catch {
      return null;
    }
  }

  async detach() {
    if (this.client) {
      try { await this.client.close(); } catch {}
      this.client = null;
      this.attached = false;
    }
  }
}

async function listTargets(port = 9222) {
  return CDP.List({ port });
}

module.exports = { TargetWatcher, listTargets, MAGIC };
