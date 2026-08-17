import { test, expect } from '@playwright/test';
import { mockApi, ROUTES } from './fixtures';

/* ═══ دخان: كل المسارات تفتح بدون أخطاء كونسول/شبكة مكسورة وبيّنة المحتوى ═══ */

test.describe('smoke', () => {
  test.beforeEach(async ({ page }) => {
    await mockApi(page);
  });

  for (const [name, path] of ROUTES) {
    test(`route — ${name}`, async ({ page }) => {
      const errors = [];
      page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
      page.on('console', (m) => { if (m.type() === 'error') errors.push('console: ' + m.text()); });
      page.on('requestfailed', (r) => errors.push('requestfailed: ' + r.url()));

      await page.goto(path);
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(300);

      expect(errors).toEqual([]);
      expect(await page.title()).toBeTruthy();
      const bodyText = await page.locator('body').innerText();
      expect(bodyText.trim().length).toBeGreaterThan(10);
    });
  }

  test('route — logout redirects home', async ({ page }) => {
    await page.goto('/#/logout');
    await page.waitForTimeout(400);
    expect(new URL(page.url()).pathname).toBe('/');
  });
});