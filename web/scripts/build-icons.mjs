/**
 * **L'identité du site, refaite depuis l'icône de l'app** (direction artistique V3.3).
 *
 * L'icône est celle de l'iPhone : Mika en buste, la bouche ouverte, sur le bleu nuit #101737
 * (`design/mika-v3/icone.html`, variante Y). Le dessin vient de `design/mika-v3/mika.js` et
 * Chromium le photographie à chaque taille : rien n'est agrandi depuis un petit PNG.
 *
 * Ce script écrit dans `public/` :
 * - `icon.svg` (l'icône vectorielle, coins arrondis), `favicon.ico` (16, 32, 48) ;
 * - `icon-32.png`, `icon-48.png`, `icon-64.png`, `icon-192.png`, `icon-512.png` (coins arrondis,
 *   fond transparent autour) et `icon.png` (256, la marque posée à côté du mot « Micabo ») ;
 * - `apple-touch-icon.png` (180, carré plein : iOS pose son propre masque) ;
 * - `icon-maskable-512.png` (Mika réduit dans la zone sûre, le fond jusqu'aux bords) ;
 * et dans `app/` les images de partage `opengraph-image.png` et `twitter-image.png`
 * (1200 × 630), avec leur texte de remplacement.
 *
 * Il faut Playwright et son Chromium (préinstallés dans l'environnement des agents, sinon
 * `npm i -g playwright && npx playwright install chromium`, puis `NODE_PATH=$(npm root -g)`).
 *
 *     # depuis la racine du dépôt (le chargeur lit les catalogues TypeScript du site)
 *     node --experimental-strip-types --import ./scripts/ts-extensions.mjs web/scripts/build-icons.mjs
 */
import { readFileSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { loadMika } from "./sync-mika.mjs";

const require = createRequire(import.meta.url);
const { chromium } = require("playwright");

const here = dirname(fileURLToPath(import.meta.url));
const WEB = resolve(here, "..");
const PUBLIC = resolve(WEB, "public");
const APP = resolve(WEB, "app");
const FONT = resolve(WEB, "app/fonts/SofiaSansCondensed-Black.woff2");
const { en } = await import(resolve(WEB, "lib/i18n/catalogs/en.ts")).catch(() => ({ en: null }));

const NIGHT = "#101737";
const MARINE = "#0B0F1C";
const mika = loadMika();

/** Mika en buste, comme l'icône de l'app : 140 % de la largeur, décalé de −20 % et +6 %. */
function bust(side, { zoom = 1.4, left = -0.2, top = 0.06 } = {}) {
  const art = mika.draw({ size: side * zoom, noShadow: true, viewBox: "-10 -30 420 420", mouth: "open", body: "#5C88FF", shade: "#3F6BE8" });
  const inner = art.slice(art.indexOf(">") + 1, art.lastIndexOf("</svg>"));
  return `<svg x="${side * left}" y="${side * top}" width="${side * zoom}" height="${side * zoom}" viewBox="-10 -30 420 420">${inner}</svg>`;
}

/** L'icône en SVG : le fond, puis Mika. `radius` en fraction du côté (0 = carré plein). */
function iconSvg(side, { radius = 0.2237, frame } = {}) {
  const r = side * radius;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${side} ${side}" width="${side}" height="${side}">`
    + `<title>Micabo</title>`
    + `<defs><clipPath id="c"><rect width="${side}" height="${side}" rx="${r}" ry="${r}"/></clipPath></defs>`
    + `<g clip-path="url(#c)"><rect width="${side}" height="${side}" fill="${NIGHT}"/>${bust(side, frame)}</g></svg>`;
}

const browser = await chromium.launch();

async function png(html, width, height, target, { transparent = true } = {}) {
  const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: 1 });
  await page.setContent(`<!doctype html><html><body style="margin:0;background:transparent">${html}</body></html>`);
  await page.evaluate(() => document.fonts.ready);
  const buffer = await page.screenshot({ omitBackground: transparent, clip: { x: 0, y: 0, width, height } });
  await page.close();
  if (target) writeFileSync(target, buffer);
  return buffer;
}

// Le SVG : 64 unités suffisent, le dessin est vectoriel.
writeFileSync(resolve(PUBLIC, "icon.svg"), iconSvg(64) + "\n");

// Les PNG à coins arrondis.
const rounded = {};
for (const side of [16, 32, 48, 64, 192, 256, 512]) {
  rounded[side] = await png(iconSvg(side), side, side);
}
for (const side of [32, 48, 64, 192, 512]) writeFileSync(resolve(PUBLIC, `icon-${side}.png`), rounded[side]);
writeFileSync(resolve(PUBLIC, "icon.png"), rounded[256]);

// iOS : un carré plein, sans transparence.
await png(iconSvg(180, { radius: 0 }), 180, 180, resolve(PUBLIC, "apple-touch-icon.png"), { transparent: false });

// Android : le fond jusqu'aux bords, Mika tenu dans les 80 % du centre.
await png(
  iconSvg(512, { radius: 0, frame: { zoom: 1.4 * 0.8, left: 0.1 - 0.2 * 0.8, top: 0.1 + 0.06 * 0.8 } }),
  512,
  512,
  resolve(PUBLIC, "icon-maskable-512.png"),
  { transparent: false },
);

// favicon.ico : trois PNG dans un conteneur ICO.
{
  const images = [16, 32, 48].map((side) => ({ side, data: rounded[side] }));
  const header = Buffer.alloc(6 + 16 * images.length);
  header.writeUInt16LE(0, 0);
  header.writeUInt16LE(1, 2);
  header.writeUInt16LE(images.length, 4);
  let offset = header.length;
  images.forEach(({ side, data }, index) => {
    const at = 6 + index * 16;
    header.writeUInt8(side, at);
    header.writeUInt8(side, at + 1);
    header.writeUInt8(0, at + 2);
    header.writeUInt8(0, at + 3);
    header.writeUInt16LE(1, at + 4);
    header.writeUInt16LE(32, at + 6);
    header.writeUInt32LE(data.length, at + 8);
    header.writeUInt32LE(offset, at + 12);
    offset += data.length;
  });
  writeFileSync(resolve(PUBLIC, "favicon.ico"), Buffer.concat([header, ...images.map((image) => image.data)]));
}

// L'image de partage : le marine, la marque, la phrase du site, et Mika qui salue.
{
  const font = readFileSync(FONT).toString("base64");
  const before = en?.landing.titleBefore ?? "Learn anything,";
  const accent = en?.landing.titleAccent ?? "step by step";
  const line = en?.landing.ogDescriptionShort ?? "";
  const wave = mika.draw({ size: 420, noShadow: true, viewBox: "-10 -30 420 420", leftArm: "wave", mouth: "open", body: "#5C88FF", shade: "#3F6BE8" });
  const html = `<style>
      @font-face { font-family: Sofia; src: url(data:font/woff2;base64,${font}) format("woff2"); font-weight: 900; }
      .og { width: 1200px; height: 630px; box-sizing: border-box; padding: 64px 72px; position: relative; overflow: hidden;
            background: radial-gradient(ellipse 60% 70% at 78% 40%, #18224A 0%, ${MARINE} 70%); color: #F5F6FB;
            font-family: -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; display: flex; flex-direction: column; justify-content: space-between; }
      .brand { display: flex; align-items: center; gap: 16px; font: 900 40px/1 Sofia; }
      .brand > svg { width: 64px; height: 64px; }
      h1 { margin: 0; font: 900 84px/0.98 Sofia; letter-spacing: -0.4px; max-width: 640px; }
      h1 span { color: #7FA2FF; }
      p { margin: 20px 0 0; font-size: 27px; line-height: 1.35; color: #A9B1C6; max-width: 600px; font-weight: 500; }
      .mika { position: absolute; right: 56px; top: 50%; transform: translateY(-46%); }
    </style>
    <div class="og">
      <div class="brand">${iconSvg(64)}Micabo</div>
      <div><h1>${before} <span>${accent}</span>.</h1><p>${line}</p></div>
      <div class="mika">${wave}</div>
    </div>`;
  const buffer = await png(html, 1200, 630, null, { transparent: false });
  writeFileSync(resolve(APP, "opengraph-image.png"), buffer);
  writeFileSync(resolve(APP, "twitter-image.png"), buffer);
  const alt = `Micabo - ${before} ${accent}.`;
  writeFileSync(resolve(APP, "opengraph-image.alt.txt"), alt);
  writeFileSync(resolve(APP, "twitter-image.alt.txt"), alt);
}

await browser.close();
console.log("Icônes et images de partage écrites.");
