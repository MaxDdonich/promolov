const { chromium } = require('playwright');

const targets = [
  { name: 'Яндекс Еда', url: 'https://eda.yandex.ru/' },
  { name: 'Купер', url: 'https://kuper.ru/' }
];

(async () => {
  const browser = await chromium.launch({ headless: true });
  for (const target of targets) {
    const context = await browser.newContext({
      locale: 'ru-RU',
      timezoneId: 'Europe/Moscow',
      userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36'
    });
    const page = await context.newPage();
    const result = { name: target.name, url: target.url };
    try {
      const response = await page.goto(target.url, { waitUntil: 'domcontentloaded', timeout: 60000 });
      await page.waitForTimeout(6000);
      result.http = response ? response.status() : null;
      result.title = await page.title();
      const body = await page.locator('body').innerText().catch(() => '');
      result.body = body.replace(/\s+/g, ' ').slice(0, 500);
      result.loginWords = (body.match(/войти|вход|номер телефона|телефон|код из смс/gi) || []).length;
      result.promoWords = (body.match(/промокод/gi) || []).length;
      result.inputs = await page.locator('input').count();
      result.hasLoginLink = await page.locator('a,button').filter({ hasText: /войти|вход/i }).count();
    } catch (error) {
      result.error = String(error);
    }
    console.log('BROWSER_PROBE ' + JSON.stringify(result));
    await context.close();
  }
  await browser.close();
})();
