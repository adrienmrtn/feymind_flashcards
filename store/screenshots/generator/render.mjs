#!/usr/bin/env node
/**
 * **Les images de la fiche App Store, refaites depuis `index.html`.**
 *
 *   python3 store/screenshots/generator/statusbar.py     les captures, barre d'état propre
 *   node store/screenshots/generator/render.mjs [fr en …]  les images, toutes langues par défaut
 *
 * Chaque langue est une page de 7 × 1320 px, coupée en sept images de 1320 × 2868 (l'iPhone
 * 6,9″) dans `store/screenshots/<langue>/`. Ce sont ces fichiers, suivis dans le dépôt, que
 * `store/screenshots.mjs` envoie à App Store Connect : ce qui part est ce qui a été relu.
 *
 * Il faut Playwright et son Chromium, qui ne sont pas des dépendances du dépôt
 * (`npm i --no-save playwright && npx playwright install chromium`, ou `PLAYWRIGHT=<chemin>`
 * vers une installation existante).
 */

import { mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const { chromium } = await import(process.env.PLAYWRIGHT ?? "playwright");

const WIDTH = 1320;
const HEIGHT = 2868;

/** Les sept écrans, dans l'ordre de la fiche. Le nom du fichier dit ce que montre l'image. */
const SCREENS = ["01-fiches", "02-chiffres", "03-reviser", "04-quiz", "05-mika", "06-formules", "07-paquets"];

const langs = process.argv.slice(2).length ? process.argv.slice(2) : ["fr", "en", "es", "de", "tr"];
const page = pathToFileURL(resolve(here, "index.html")).href;

const browser = await chromium.launch();
const tab = await browser.newPage({ viewport: { width: WIDTH * SCREENS.length, height: HEIGHT }, deviceScaleFactor: 1 });

for (const lang of langs) {
  // Le texte se pose au chargement, d'après le fragment : changer de fragment ne suffit pas.
  await tab.goto(`${page}#${lang}`);
  await tab.reload();
  await tab.waitForFunction(
    () => document.body.dataset.ready === "1" && [...document.images].every((image) => image.complete && image.naturalWidth > 0),
  );
  const out = resolve(here, "..", lang);
  mkdirSync(out, { recursive: true });
  for (const [index, name] of SCREENS.entries()) {
    await tab.screenshot({
      path: resolve(out, `${name}.png`),
      clip: { x: index * WIDTH, y: 0, width: WIDTH, height: HEIGHT },
    });
  }
  console.log(`${lang} : ${SCREENS.length} images, tailles ${await tab.evaluate(() => document.body.dataset.sizes)}`);
}

await browser.close();
