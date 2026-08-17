import { test, expect } from '@playwright/test';
import { mockApi, ROUTES } from './fixtures';

/* ═══ لقطات ذهبية حتمية: اعتراض API + إيقاف الحركات + reduced-motion ═══
   أول تشغيل: npx playwright test --update-snapshots (توليد المرجع)
   بعدها: npx playwright test (مقارنة pixel بنسبة خطأ ≤ 2%) */

test.beforeEach(async ({ page }) => {
  await mockApi(page);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.addStyleTag({ content: '*{animation:none!important;transition:none!important}' });
});

for (const [name, path] of ROUTES) {
  test(`golden — ${name}`, async ({ page }, info) => {
    await page.goto(path);
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(500);
    expect(await page.title()).toBeTruthy();
    await expect(page.locator('main')).toContainText(/./);
    await expect(page).toHaveScreenshot(`${name}.png`, { fullPage: true, maxDiffPixelRatio: 0.02, animations: 'disabled' });
  });
}