/* ═══ فحص تجاوب برمجي — تحقق DOM عند كل مقاس (بديل القراءة البصرية) ═══
   التشغيل: npm run shots:check */
import { chromium } from '@playwright/test';
import { spawn } from 'node:child_process';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');
const PORT = 4174;

const server = spawn('npx', ['vite', 'preview', '--port', String(PORT)], { cwd: root, stdio: 'ignore' });
const ready = async (retry = 0) => {
  try { const r = await fetch(`http://localhost:${PORT}/`); if (r.ok) return true; } catch (_) {}
  if (retry > 30) return false;
  await new Promise((r) => setTimeout(r, 300));
  return ready(retry + 1);
};

const browser = await chromium.launch();
let fails = 0;
const check = (cond, label) => {
  if (!cond) { fails++; console.error('  ✗ ' + label); }
  else console.log('  ✓ ' + label);
};

if (await ready()) {
  const cases = [
    { w: 360, url: '/', tests: [
      ['الشريط السفلي ظاهر (موبايل)', async (p) => await p.isVisible('.bottom-nav')],
      ['تنقل الديسكتوب مخفي (موبايل)', async (p) => !(await p.isVisible('.nav-links'))],
      ['بحث الهيدر الثابت مخفي (موبايل)', async (p) => !(await p.isVisible('.search-desktop'))],
      ['بدون تمرير أفقي', async (p) => await p.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1)],
      ['عدّاد بطاقات المنتجات ≥ 2 بعمودين', async (p) => await p.evaluate(() => {
        const probe = document.createElement('div');
        probe.className = 'products-grid';
        probe.style.width = '100%';
        probe.style.position = 'absolute';
        probe.innerHTML = '<div style="height:1px"></div>';
        document.body.appendChild(probe);
        const cols = getComputedStyle(probe).gridTemplateColumns.split(' ').length;
        probe.remove();
        return cols >= 2;
      })],
    ]},
    { w: 768, url: '/', tests: [
      ['الشريط السفلي ظاهر (آيباد)', async (p) => await p.isVisible('.bottom-nav')],
      ['بحث الهيدر ظاهر (آيباد)', async (p) => await p.isVisible('.search-desktop')],
      ['بدون تمرير أفقي', async (p) => await p.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1)],
    ]},
    { w: 1024, url: '/', tests: [
      ['الشريط السفلي مخفي (ديسكتوب)', async (p) => !(await p.isVisible('.bottom-nav'))],
      ['تنقل الديسكتوب ظاهر', async (p) => await p.isVisible('.nav-links')],
      ['بدون تمرير أفقي', async (p) => await p.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1)],
    ]},
    { w: 1440, url: '/#/prods', tests: [
      ['سايدبار التصنيفات ظاهر (واسع)', async (p) => await p.isVisible('.sidebar')],
      ['بدون تمرير أفقي', async (p) => await p.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1)],
    ]},
  ];

  for (const c of cases) {
    console.log(`── مقاس ${c.w}px · ${c.url}`);
    const page = await browser.newPage({ viewport: { width: c.w, height: 900 } });
    await page.goto(`http://localhost:${PORT}${c.url}`, { waitUntil: 'networkidle', timeout: 20000 });
    await page.waitForTimeout(300);
    for (const [label, fn] of c.tests) {
      try { check(await fn(page), label); } catch (e) { check(false, label + ' — ' + e.message); }
    }
    await page.close();
  }
} else { fails++; console.error('✗ السيرفر ما اشتغل'); }

await browser.close();
server.kill();
console.log(fails ? `✗ انتهى مع ${fails} فشل` : '✓ كل فحوصات التجاوب ناجحة');
process.exit(fails ? 1 : 0);