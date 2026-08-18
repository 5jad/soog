/* ═══ فحص تجاوب بصري — لقطات 4 مقاسات لأهم الصفحات ═══
   التشغيل: npm run shots (بعد npm run build)
   المخرج: /tmp/zaboon-shots/<page>-<width>.png */
import { chromium } from '@playwright/test';
import { spawn } from 'node:child_process';
import { mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');

const PORT = 4173;
const OUT = '/tmp/zaboon-shots';
mkdirSync(OUT, { recursive: true });

const pages = [
  ['home', '/'],
  ['stores', '/#/stores'],
  ['prods', '/#/prods'],
  ['offers', '/#/offers'],
  ['product', '/#/product/1'],
  ['cart', '/#/cart'],
  ['account', '/#/account'],
  ['vendor', '/#/vendor'],
  ['delivery', '/#/delivery'],
];

const widths = [360, 768, 1024, 1440];

console.log('⏳ تشغيل vite preview…');
const server = spawn('npx', ['vite', 'preview', '--port', String(PORT)], { cwd: root, stdio: 'ignore' });

const ready = async (retry = 0) => {
  try {
    const r = await fetch(`http://localhost:${PORT}/`);
    if (r.ok) return true;
  } catch (_) {}
  if (retry > 30) return false;
  await new Promise((r) => setTimeout(r, 300));
  return ready(retry + 1);
};

const browser = await chromium.launch();
let failures = 0;
if (await ready()) {
  for (const [name, url] of pages) {
    for (const w of widths) {
      const page = await browser.newPage({ viewport: { width: w, height: 900 }, deviceScaleFactor: 1 });
      try {
        await page.goto(`http://localhost:${PORT}${url}`, { waitUntil: 'networkidle', timeout: 20000 });
        await page.waitForTimeout(500);
        await page.screenshot({ path: join(OUT, `${name}-${w}.png`), fullPage: true });
        console.log(`✓ ${name} @ ${w}px`);
      } catch (e) {
        failures++;
        console.error(`✗ ${name} @ ${w}px — ${e.message}`);
      }
      await page.close();
    }
  }
} else {
  failures++;
  console.error('✗ السيرفر ما اشتغل');
}
await browser.close();
server.kill();
console.log(failures ? `انتهى مع ${failures} مشكلة — لقطات: ${OUT}` : '✓ فحص التجاوب اكتمل بدون أخطاء — لقطات: ' + OUT);
process.exit(failures ? 1 : 0);