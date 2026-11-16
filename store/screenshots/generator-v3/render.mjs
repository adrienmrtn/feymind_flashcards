#!/usr/bin/env node
/**
 * **Les images de la fiche App Store, DA V3, refaites depuis `index.html` dans chaque langue.**
 *
 *   node store/screenshots/generator-v3/render.mjs                toutes les langues de `i18n.js`
 *   node store/screenshots/generator-v3/render.mjs fr de          seulement celles-ci
 *   OUT=/tmp/essai node store/screenshots/generator-v3/render.mjs  ailleurs que dans le dépôt
 *
 * La page fait 7 × 1320 px ; elle est coupée en sept images de 1320 × 2868 (l'iPhone 6,9″),
 * écrites dans `store/screenshots/<langue>/` (les anciennes images du dossier sont retirées).
 * Le 6,3″ se fait ensuite avec `python3 store/screenshots/generator/resize.py <dossier>`.
 *
 * Il faut Playwright (`npm i --no-save playwright`, ou `PLAYWRIGHT=<chemin>`) et un Chromium :
 * le sien, ou celui du système avec `CHROME=/usr/bin/google-chrome`.
 *
 * Le japonais des titres utilise un extrait de Noto Sans CJK (`fonts/noto-sans-jp-subset-900.woff2`)
 * qui ne contient que les caractères de `i18n.js` : à refaire si ces titres changent (voir LISEZMOI.md).
 */

import { mkdirSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import vm from "node:vm";

const here = dirname(fileURLToPath(import.meta.url));
const { chromium } = await import(process.env.PLAYWRIGHT ?? "playwright");

const WIDTH = 1320;
const HEIGHT = 2868;
const SCREENS = ["01-mika", "02-fiche", "03-parcours", "04-quiz", "05-question", "06-flashcards", "07-examens"];

const sandbox = { window: {} };
vm.runInNewContext(readFileSync(resolve(here, "i18n.js"), "utf8"), sandbox);
const all = Object.keys(sandbox.window.I18N);
const wanted = process.argv.slice(2);
const unknown = wanted.filter((lang) => !all.includes(lang));
if (unknown.length) {
  console.error(`langues inconnues : ${unknown.join(", ")} (connues : ${all.join(", ")})`);
  process.exit(1);
}
const langs = wanted.length ? wanted : all;
const outRoot = resolve(process.env.OUT ?? resolve(here, ".."));

const browser = await chromium.launch(process.env.CHROME ? { executablePath: process.env.CHROME } : {});
const tab = await browser.newPage({ viewport: { width: WIDTH * SCREENS.length, height: HEIGHT }, deviceScaleFactor: 1 });
const page = pathToFileURL(resolve(here, "index.html")).href;

for (const lang of langs) {
  const out = join(outRoot, lang);
  mkdirSync(out, { recursive: true });
  for (const name of readdirSync(out)) if (name.endsWith(".png")) rmSync(join(out, name));

  await tab.goto(`${page}?lang=${encodeURIComponent(lang)}`);
  await tab.waitForFunction(() => document.body.dataset.ready === "1");
  for (const [index, name] of SCREENS.entries()) {
    await tab.screenshot({ path: join(out, `${name}.png`), clip: { x: index * WIDTH, y: 0, width: WIDTH, height: HEIGHT } });
  }
  console.log(`${lang.padEnd(6)} ${SCREENS.length} images, tailles ${await tab.evaluate(() => document.body.dataset.sizes)}`);
}
await browser.close();
