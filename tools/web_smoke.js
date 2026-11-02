// Web export smoke test: node tools/web_smoke.js [build/web]
// Serves the export, boots it in headless Chromium, waits for the main menu,
// clicks "Tutorial" and checks it starts, with zero console errors.
const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const root = path.resolve(process.argv[2] || 'build/web');
const types = { '.html': 'text/html', '.js': 'application/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const p = path.join(root, decodeURIComponent(req.url.split('?')[0]) === '/' ? 'index.html' : decodeURIComponent(req.url.split('?')[0]));
  if (!p.startsWith(root) || !fs.existsSync(p)) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'Content-Type': types[path.extname(p)] || 'application/octet-stream' });
  fs.createReadStream(p).pipe(res);
});

(async () => {
  await new Promise(r => server.listen(8765, r));
  const browser = await chromium.launch({ args: ['--enable-unsafe-swiftshader', '--use-angle=swiftshader', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const errors = [];
  const logs = [];
  page.on('console', m => { logs.push(`[${m.type()}] ${m.text()}`); if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', e => errors.push('pageerror: ' + e.message));
  const waitLog = (needle, ms) => new Promise((resolve, reject) => {
    const t0 = Date.now();
    const iv = setInterval(() => {
      if (logs.some(l => l.includes(needle))) { clearInterval(iv); resolve(); }
      else if (Date.now() - t0 > ms) { clearInterval(iv); reject(new Error('timeout waiting for ' + needle)); }
    }, 200);
  });
  let ok = true;
  try {
    await page.goto('http://localhost:8765/index.html');
    await waitLog('MAIN_MENU_READY', 90000);
    await page.waitForTimeout(1500);
    await page.screenshot({ path: path.join(root, '..', 'web_menu.png') });
    // Tutorial button (first menu button) — see scenes/menu_screen.gd layout.
    await page.mouse.click(330, 385);
    await waitLog('TUTORIAL_STARTED', 20000);
    await page.waitForTimeout(3000);
    await page.screenshot({ path: path.join(root, '..', 'web_tutorial.png') });
  } catch (e) {
    ok = false;
    console.log('FAIL:', e.message);
  }
  await browser.close();
  server.close();
  console.log(logs.filter(l => !l.startsWith('[debug]')).slice(0, 40).join('\n'));
  console.log(`console errors: ${errors.length}`);
  errors.forEach(e => console.log('  ' + e));
  const pass = ok && errors.length === 0;
  console.log(pass ? 'WEB SMOKE: PASS' : 'WEB SMOKE: FAIL');
  process.exit(pass ? 0 : 1);
})();
