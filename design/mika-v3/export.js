#!/usr/bin/env node
// **Les images de Mika qui ne se dessinent pas dans le code**, exportées du SVG (`mika.js`)
// par Chromium : le Mika de l'écran de lancement, la planche des douze expressions et, quand
// on le demande, l'icône de l'app.
//
// Tout le reste de Mika est vectoriel, dessiné par SwiftUI (`MikaArt.swift`) : il n'y a plus
// d'image d'expression à refaire.
//
//     node design/mika-v3/export.js                    # l'image de lancement et la planche
//     node design/mika-v3/export.js --propositions D   # écrit aussi les icônes A, B et C (1024 px) dans D
//     node design/mika-v3/export.js --icone Y          # refait l'icône de l'app depuis `icone.html`
//
// **L'icône de l'app n'est pas refaite par défaut** : `AppIcon.png` est déjà l'export de la
// variante Y de `icone.html` (Mika en buste sur bleu nuit). `--icone` le réécrit (1024 px, sans
// transparence ni coins arrondis) ; avec `--marque`, il réécrit aussi `BrandMark` (384 px).
//
// Il faut Playwright et son Chromium (`npm i -g playwright && npx playwright install chromium`,
// puis `NODE_PATH=$(npm root -g)` si Node ne le trouve pas).

const path = require('path');
const fs = require('fs');
const { chromium } = require('playwright');

const here = __dirname;
const root = path.resolve(here, '../..');
const assets = path.join(root, 'Micabo/Resources/Assets.xcassets');
const page = (name, query = '') => 'file://' + path.join(here, name) + query;

/** La valeur qui suit un drapeau de la ligne de commande, s'il est là. */
function option(flag) {
  const index = process.argv.indexOf(flag);
  return index > 0 ? process.argv[index + 1] : null;
}

async function main() {
  const proposals = option('--propositions');
  const chosen = option('--icone');
  const browser = await chromium.launch();

  // Une icône carrée, sans transparence ni coins arrondis : Chromium écrit un PNG sans canal alpha.
  async function icon(variant, side, target) {
    const tab = await browser.newPage({ viewport: { width: side, height: side }, deviceScaleFactor: 1 });
    await tab.goto(page('icone.html', `?v=${variant}&s=${side}`));
    await tab.screenshot({ path: target, clip: { x: 0, y: 0, width: side, height: side } });
    await tab.close();
    console.log(path.relative(root, target));
  }

  // Le Mika de l'écran de lancement : 200 points, fond transparent, à 2 et 3 pixels par point.
  for (const scale of [2, 3]) {
    const tab = await browser.newPage({ viewport: { width: 200, height: 200 }, deviceScaleFactor: scale });
    await tab.goto(page('lancement.html'));
    const target = path.join(assets, `LaunchMika.imageset/LaunchMika@${scale}x.png`);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    await tab.screenshot({ path: target, omitBackground: true, clip: { x: 0, y: 0, width: 200, height: 200 } });
    await tab.close();
    console.log(path.relative(root, target));
  }

  // La planche des douze expressions, sur le marine puis sur le clair.
  {
    const tab = await browser.newPage({ viewport: { width: 1200, height: 904 }, deviceScaleFactor: 1 });
    await tab.goto(page('apercu.html'));
    const target = path.join(here, 'mika-expressions.png');
    await tab.screenshot({ path: target, fullPage: true });
    await tab.close();
    console.log(path.relative(root, target));
  }

  // Les propositions d'icône, pour les montrer.
  if (proposals) {
    const folder = path.resolve(proposals);
    fs.mkdirSync(folder, { recursive: true });
    const names = { Y: 'icone-Y-bleu-nuit-1024.png', A: 'icone-A-marine-1024.png', B: 'icone-B-jaune-1024.png', C: 'icone-C-bleu-profond-1024.png' };
    for (const variant of Object.keys(names)) {
      await icon(variant, 1024, path.join(folder, names[variant]));
    }
  }

  // L'icône de l'app et, sur demande, la marque posée dans l'app (la même, en petit).
  if (chosen) {
    await icon(chosen, 1024, path.join(assets, 'AppIcon.appiconset/AppIcon.png'));
    if (process.argv.includes('--marque')) {
      await icon(chosen, 384, path.join(assets, 'BrandMark.imageset/BrandMark.png'));
    }
  }

  await browser.close();
}

main().catch((error) => { console.error(error); process.exit(1); });
