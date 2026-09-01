/**
 * Coupe le halo gris du stylo.
 *
 * Le masque arrondi laisse des pixels bleu à demi transparents. Sur un fond
 * clair, ce bleu pâle se lit comme un filet gris autour du squircle. On
 * recadre, puis on force l'alpha à 0 ou 255.
 *
 * Usage : node web/scripts/clean-icon-fringe.mjs
 */
import { existsSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const REPO = resolve(ROOT, "..");
const OUT = resolve(ROOT, "public");
const require = createRequire(import.meta.url);
const sharpCandidates = [
  "sharp",
  resolve(ROOT, "node_modules/.pnpm/sharp@0.35.3_@types+node@26.3.0/node_modules/sharp"),
  resolve(REPO, "node_modules/.pnpm/sharp@0.35.3_@types+node@26.3.0/node_modules/sharp"),
];
const sharpPath = sharpCandidates.find((candidate) => {
  try {
    require.resolve(candidate);
    return true;
  } catch {
    return existsSync(candidate);
  }
});
if (!sharpPath) {
  console.error("sharp introuvable. Lancer depuis web/ après pnpm install.");
  process.exit(1);
}
const sharp = require(sharpPath);

const BLUE = { r: 34, g: 136, b: 250 };
const RADIUS = 0.223;
const INSET_RATIO = 0.012;
const ALPHA_CUT = 160;

function tightMask(size) {
  const inset = Math.max(1, Math.round(size * INSET_RATIO));
  const inner = size - inset * 2;
  const r = Math.max(1, Math.round(inner * RADIUS));
  return Buffer.from(
    `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}"><rect x="${inset}" y="${inset}" width="${inner}" height="${inner}" rx="${r}" ry="${r}" fill="#fff"/></svg>`,
  );
}

async function cleanRounded(path) {
  const image = sharp(path);
  const { width, height } = await image.metadata();
  const size = Math.min(width ?? 0, height ?? 0);
  if (!size) throw new Error(`Taille illisible : ${path}`);

  const remasked = await sharp(path)
    .ensureAlpha()
    .composite([{ input: tightMask(size), blend: "dest-in" }])
    .raw()
    .toBuffer({ resolveWithObject: true });

  const { data, info } = remasked;

  for (let i = 0; i < data.length; i += 4) {
    const alpha = data[i + 3];
    if (alpha < ALPHA_CUT) {
      data[i] = 0;
      data[i + 1] = 0;
      data[i + 2] = 0;
      data[i + 3] = 0;
      continue;
    }

    data[i + 3] = 255;
    const r = data[i];
    const g = data[i + 1];
    const b = data[i + 2];
    const isStylus = r > 170 && g > 170 && b > 170;
    const isBlue = b > 150 && r < 130 && g < 210;
    if (!isStylus && !isBlue) {
      data[i] = BLUE.r;
      data[i + 1] = BLUE.g;
      data[i + 2] = BLUE.b;
    }
  }

  return sharp(data, {
    raw: { width: info.width, height: info.height, channels: 4 },
  })
    .png({ compressionLevel: 9 })
    .toBuffer();
}

const rounded = [
  "icon.png",
  "icon-32.png",
  "icon-48.png",
  "icon-64.png",
  "icon-192.png",
  "icon-512.png",
];

for (const name of rounded) {
  const path = resolve(OUT, name);
  const cleaned = await cleanRounded(path);
  writeFileSync(path, cleaned);
  console.log(`cleaned ${name}`);
}

const icon64 = await sharp(resolve(OUT, "icon-64.png")).png().toBuffer();
const svg = [
  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">',
  "<title>Micabo</title>",
  `<image href="data:image/png;base64,${icon64.toString("base64")}" width="64" height="64" />`,
  "</svg>",
  "",
].join("");
writeFileSync(resolve(OUT, "icon.svg"), svg);
console.log("cleaned icon.svg");
