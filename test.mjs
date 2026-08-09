import puppeteer from 'puppeteer';
const browser = await puppeteer.launch();
const page = await browser.newPage();
page.on('console', msg => console.log(msg.text()));
await page.setContent(`
<script>
  const VIEWS = { a: renderA };
</script>
<script>
  function renderA() {}
</script>
`);
await browser.close();
