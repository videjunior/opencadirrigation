// Renders the sharing image (Open Graph / Twitter card, 1200 × 630) of every language page from the page itself:
// its logo and its heading, in the browser's own text shaping, so Arabic, Indic, Chinese and Japanese read right.
// The English root keeps web/og-image.png; the others get web/og/og-image-<code>.jpg, which tool/site.dart names in
// og:image, twitter:image and the JSON-LD of each page.
//
//   npm install playwright-core   (once, anywhere on the module path)
//   node tool/og/render_og.js [path to Chrome]
//
// Run from the repository root after `dart run tool/gen_site.dart`, then run the generator again: the pages carry the
// version of each image in its address.
'use strict';
const { chromium } = require('playwright-core');
const fs = require('fs');
const http = require('http');
const path = require('path');

const WEB = path.resolve('web');
const CHROME = process.argv[2] || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const TYPES = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.png': 'image/png', '.webp': 'image/webp', '.json': 'application/json', '.css': 'text/css' };

const server = http.createServer((req, res) => {
  let p = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  if (p.endsWith('/')) p += 'index.html';
  const file = path.join(WEB, p);
  if (!file.startsWith(WEB) || !fs.existsSync(file)) {
    res.writeHead(404);
    res.end();
    return;
  }
  res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
});

// The card: the page's header alone, centred on the page colours.
const CARD_CSS = `
  html, body { background: #14171B !important; overflow: hidden !important; }
  #oci-landing .wrap > *:not(header), #oci-landing footer, #oci-consent, #oci-landing .cta, #oci-landing .bar, #oci-landing .status, #oci-landing .tagline, noscript { display: none !important; }
  #oci-landing .wrap { max-width: none !important; height: 630px; box-sizing: border-box; padding: 0 70px !important; display: flex; align-items: center; justify-content: center; }
  #oci-landing header { padding: 0 !important; }
  #oci-landing header img { width: 560px !important; }
  #oci-landing h1 { font-size: 48px !important; line-height: 1.25 !important; margin: 34px 0 0 !important; color: #ECEFF1 !important; }
  #oci-landing::after { content: ''; position: fixed; left: 0; right: 0; bottom: 0; height: 12px; background: linear-gradient(90deg, #0D47A1, #29B6F6); }
`;

(async () => {
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const root = `http://127.0.0.1:${server.address().port}`;
  const browser = await chromium.launch({ executablePath: CHROME, headless: true });
  const page = await browser.newPage({ viewport: { width: 1200, height: 630 }, deviceScaleFactor: 1 });
  fs.mkdirSync(path.join(WEB, 'og'), { recursive: true });
  const codes = fs.readdirSync(WEB).filter((d) => /^[a-z]{2}$/.test(d) && d !== 'en' && fs.existsSync(path.join(WEB, d, 'index.html'))).sort();
  for (const code of codes) {
    await page.goto(`${root}/${code}/`);
    await page.addStyleTag({ content: CARD_CSS });
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(300);
    const out = path.join(WEB, 'og', `og-image-${code}.jpg`);
    await page.screenshot({ path: out, type: 'jpeg', quality: 86 });
    console.log(out);
  }
  await browser.close();
  server.close();
})();
