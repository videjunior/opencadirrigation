// Renders the social preview image of the GitHub repository (1280 × 640, shown when a link to the repository is
// shared): the logo, the heading of the English page and a line of facts, on the colours of the site. Chrome's own
// headless screenshot does the drawing, so nothing needs installing:
//
//   node tool/og/render_social.js [path to Chrome]
//
// Run from the repository root (after `dart run tool/gen_site.dart`, which writes the heading into web/index.html).
// It writes docs/github/social-preview.png, which the owner uploads in the repository settings (docs/GITHUB.md).
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const CHROME = process.argv[2] || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const OUT = path.resolve('docs/github/social-preview.png');
const LOGO = path.resolve('web/brand/logo-horizontal-1040.webp');

function esc(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

// the heading of the English page, as tool/site.dart writes it
const index = fs.readFileSync(path.resolve('web/index.html'), 'utf8');
const h1 = (/<h1>([^<]+)<\/h1>/.exec(index) || [null, 'Irrigation design software with an AI assistant'])[1];
const facts = ['opencadirrigation.com', 'free and open source (MIT)', '20 languages', 'runs in the browser'];

const card = `<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><style>
  html, body { margin: 0; width: 1280px; height: 640px; overflow: hidden; background: #14171B; }
  body { font: 16px -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; color: #ECEFF1; display: flex; flex-direction: column; align-items: center; justify-content: center; }
  img { width: 620px; height: auto; filter: drop-shadow(0 8px 28px rgba(0,0,0,.5)); }
  h1 { font-size: 46px; line-height: 1.22; font-weight: 700; text-align: center; max-width: 1080px; margin: 34px 0 18px; }
  p { font-size: 25px; color: #90CAF9; margin: 0; letter-spacing: .2px; }
  .bar { position: fixed; left: 0; right: 0; bottom: 0; height: 14px; background: linear-gradient(90deg, #0D47A1, #29B6F6); }
</style></head><body>
  <img src="file://${LOGO}" alt="OpenCADIrrigation">
  <h1>${h1}</h1>
  <p>${esc(facts.join('  ·  '))}</p>
  <div class="bar"></div>
</body></html>`;

const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'oci-social-'));
const html = path.join(dir, 'card.html');
fs.writeFileSync(html, card);
fs.mkdirSync(path.dirname(OUT), { recursive: true });
try {
  execFileSync(CHROME, [
    '--headless=new',
    '--disable-gpu',
    '--hide-scrollbars',
    '--force-device-scale-factor=1',
    '--allow-file-access-from-files',
    `--user-data-dir=${path.join(dir, 'profile')}`,
    '--window-size=1280,640',
    `--screenshot=${OUT}`,
    `file://${html}`,
  ], { stdio: 'pipe', timeout: 60000 });
} finally {
  fs.rmSync(dir, { recursive: true, force: true });
}
const png = fs.readFileSync(OUT);
// PNG header: width and height at bytes 16 and 20
console.log(`${path.relative(process.cwd(), OUT)}: ${png.readUInt32BE(16)} × ${png.readUInt32BE(20)}, ${(png.length / 1024).toFixed(0)} kB`);
