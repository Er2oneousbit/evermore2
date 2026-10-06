// =============================================================================
// build_character.js  -  Export an LPC character sheet + credits, hands-free
// -----------------------------------------------------------------------------
// WHAT:  Opens the hosted Universal LPC Spritesheet Character Generator in a
//        headless browser, applies a character "recipe" (the URL hash the
//        generator itself uses), and saves:
//            <out>/sheet.png      832x3456 universal sheet (13x54 frames of 64x64)
//            <out>/credits.txt    human-readable credits (REQUIRED by license)
//            <out>/credits.csv    same, machine-readable
//            <out>/preview.png    screenshot of the generator page (sanity check)
//
// WHY:   Re-making a character after tweaking an outfit is one command, and
//        the recipe lives in git (tools/lpc/characters.json), not in someone's
//        browser history.
//
// USAGE: node tools/lpc/build_character.js <character key | "#hash"> <out dir>
//        node tools/lpc/build_character.js kid assets/characters/kid/build
//   Needs: Node 18+ and Playwright (npm i -g playwright && npx playwright install chromium)
//   Behind a proxy: HTTPS_PROXY is picked up automatically.
//
// FIND A RECIPE: build the character in the web generator
//   https://liberatedpixelcup.github.io/Universal-LPC-Spritesheet-Character-Generator/
//   then copy everything from '#' onward in the address bar.
//
// Written with help from Claude (Anthropic) via Claude Code.
// Made with ❤️ from your friendly hacker - er2oneousbit
// =============================================================================
const path = require('path');
const fs = require('fs');

let chromium;
try {
  ({ chromium } = require('playwright'));
} catch {
  // Fall back to a global install (npm i -g playwright).
  const globalRoot = require('child_process').execSync('npm root -g').toString().trim();
  ({ chromium } = require(path.join(globalRoot, 'playwright')));
}

const GENERATOR_URL = 'https://liberatedpixelcup.github.io/Universal-LPC-Spritesheet-Character-Generator/';
const RECIPES = JSON.parse(fs.readFileSync(path.join(__dirname, 'characters.json'), 'utf8'));

function usage(msg) {
  if (msg) console.error('ERROR: ' + msg);
  console.error('Usage: node tools/lpc/build_character.js <' + Object.keys(RECIPES).filter(k => !k.startsWith('_')).join('|') + '|"#hash"> <out dir>');
  process.exit(2);
}

(async () => {
  const [which, outDir] = process.argv.slice(2);
  if (!which || !outDir) usage();
  const hash = which.startsWith('#') ? which : (RECIPES[which] || {}).hash;
  if (!hash) usage(`unknown character '${which}'`);
  fs.mkdirSync(outDir, { recursive: true });

  const launch = process.env.HTTPS_PROXY ? { proxy: { server: process.env.HTTPS_PROXY } } : {};
  const browser = await chromium.launch(launch);
  try {
    const ctx = await browser.newContext({ acceptDownloads: true, viewport: { width: 1600, height: 1400 } });
    const page = await ctx.newPage();
    console.log('Loading generator with recipe', hash);
    await page.goto(GENERATOR_URL + hash, { waitUntil: 'networkidle', timeout: 120000 });
    await page.waitForTimeout(6000); // sprite layers finish compositing after network idle
    await page.screenshot({ path: path.join(outDir, 'preview.png') });
    const downloads = [['Spritesheet (PNG)', 'sheet.png'], ['Credits (TXT)', 'credits.txt'], ['Credits (CSV)', 'credits.csv']];
    for (const [label, file] of downloads) {
      const [dl] = await Promise.all([
        page.waitForEvent('download', { timeout: 60000 }),
        page.getByRole('button', { name: label, exact: true }).first().click(),
      ]);
      await dl.saveAs(path.join(outDir, file));
      console.log('saved', path.join(outDir, file));
    }
  } finally {
    await browser.close();
  }
})().catch(e => { console.error('FAILED:', e.message); process.exit(1); });
