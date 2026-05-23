module.exports = `
(() => {
  if (window.__BUGSNAP_INSTALLED__) return;
  window.__BUGSNAP_INSTALLED__ = true;
  var MAGIC = '__BUGSNAP__';
  function send(type, data) {
    try { console.log(MAGIC, JSON.stringify({ type: type, data: data, ts: Date.now() })); } catch (e) {}
  }
  function describe(el) {
    if (!el || !el.tagName) return null;
    var attr = function (name) {
      try { return el.getAttribute ? el.getAttribute(name) : undefined; } catch (e) { return undefined; }
    };
    return {
      tag: el.tagName,
      id: el.id || undefined,
      classes: (typeof el.className === 'string' && el.className) ? el.className.slice(0, 200) : undefined,
      role: attr('role') || undefined,
      ariaLabel: attr('aria-label') || undefined,
      testId: attr('data-testid') || attr('data-test-id') || attr('data-test') || undefined,
      href: el.tagName === 'A' ? attr('href') : undefined,
      name: el.name || undefined,
      type: el.type || undefined,
      text: (el.innerText || '').toString().replace(/\\s+/g, ' ').trim().slice(0, 100) || undefined,
    };
  }
  document.addEventListener('click', function (e) {
    send('click', { target: describe(e.target), x: e.clientX, y: e.clientY });
  }, true);
  document.addEventListener('submit', function (e) {
    send('submit', { target: describe(e.target) });
  }, true);
  document.addEventListener('input', function (e) {
    var d = describe(e.target);
    if (d) d.text = undefined; // never capture input contents
    send('input', { target: d });
  }, true);
  document.addEventListener('change', function (e) {
    var d = describe(e.target);
    if (d) d.text = undefined;
    send('change', { target: d });
  }, true);
  window.addEventListener('error', function (e) {
    send('jserror', {
      message: e.message,
      filename: e.filename,
      lineno: e.lineno,
      colno: e.colno,
      stack: e.error && e.error.stack ? String(e.error.stack).slice(0, 2000) : undefined,
    });
  });
  window.addEventListener('unhandledrejection', function (e) {
    var r = e.reason;
    send('unhandledrejection', {
      reason: r && (r.stack || r.message || String(r)).slice(0, 2000),
    });
  });
})();
`;
