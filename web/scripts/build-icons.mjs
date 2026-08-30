/**
 * Construit les icônes du site à partir du rendu 3D du stylo.
 *
 * Le fichier source est un carré aux coins droits. On pose un masque arrondi
 * (~22 %, comme une icône d'écran d'accueil) sur tout ce qui s'affiche dans
 * un onglet ou à côté du mot « Micabo ». iOS applique son propre masque :
 * `apple-touch-icon.png` reste donc un carré plein.
 *
 * Usage :
 *   node web/scripts/build-icons.mjs <source.png>
 */
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const OUT = resolve(ROOT, "public");
const require = createRequire(import.meta.url);
const sharpCandidates = [
  "sharp",
  resolve(ROOT, "node_modules/.pnpm/sharp@0.35.3_@types+node@26.3.0/node_modules/sharp"),
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
const RADIUS = 0.22;
const BLUE = { r: 34, g: 136, b: 250 };

const source = process.argv[2];
if (!source) {
  console.error("Usage: node web/scripts/build-icons.mjs <source.png>");
  process.exit(1);
}

mkdirSync(OUT, { recursive: true });

function roundedMask(size) {
  const r = Math.round(size * RADIUS);
  return Buffer.from(
    `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}"><rect width="${size}" height="${size}" rx="${r}" ry="${r}" fill="#fff"/></svg>`,
  );
}

async function roundedPng(size) {
  const pipeline = sharp(source)
    .resize(size, size, { fit: "cover" })
    .composite([{ input: roundedMask(size), blend: "dest-in" }]);
  // Sous 48 px le dégradé 3D se perd de toute façon : une palette tient
  // dans un favicon. Au-dessus, on garde les ombres du stylo.
  return size < 48
    ? pipeline.png({ compressionLevel: 9, palette: true, colours: 48 }).toBuffer()
    : pipeline.png({ compressionLevel: 9 }).toBuffer();
}

async function squarePng(size) {
  return sharp(source)
    .resize(size, size, { fit: "cover" })
    .flatten({ background: BLUE })
    .png({ compressionLevel: 9 })
    .toBuffer();
}

function pngsToIco(entries) {
  const header = 6 + 16 * entries.length;
  let offset = header;
  const parts = entries.map((entry) => {
    const part = { ...entry, offset, bytes: entry.png.length };
    offset += entry.png.length;
    return part;
  });
  const out = Buffer.alloc(offset);
  out.writeUInt16LE(0, 0);
  out.writeUInt16LE(1, 2);
  out.writeUInt16LE(entries.length, 4);
  let cursor = 6;
  for (const part of parts) {
    out[cursor] = part.size >= 256 ? 0 : part.size;
    out[cursor + 1] = part.size >= 256 ? 0 : part.size;
    out[cursor + 2] = 0;
    out[cursor + 3] = 0;
    out.writeUInt16LE(1, cursor + 4);
    out.writeUInt16LE(32, cursor + 6);
    out.writeUInt32LE(part.bytes, cursor + 8);
    out.writeUInt32LE(part.offset, cursor + 12);
    cursor += 16;
  }
  for (const part of parts) {
    part.png.copy(out, part.offset);
  }
  return out;
}

const icon32 = await roundedPng(32);
const icon64 = await roundedPng(64);
const icon256 = await roundedPng(256);
const icon192 = await roundedPng(192);
const icon512 = await roundedPng(512);
const apple = await squarePng(180);

const maskInner = 390;
const padded = await sharp(source)
  .resize(maskInner, maskInner, { fit: "cover" })
  .png()
  .toBuffer();
const maskable = await sharp({
  create: { width: 512, height: 512, channels: 3, background: BLUE },
})
  .composite([{ input: padded, left: Math.round((512 - maskInner) / 2), top: Math.round((512 - maskInner) / 2) }])
  .png({ compressionLevel: 9 })
  .toBuffer();

const icon16 = await roundedPng(16);
const ico = pngsToIco([
  { size: 16, png: icon16 },
  { size: 32, png: icon32 },
]);

writeFileSync(resolve(OUT, "icon.png"), icon256);
writeFileSync(resolve(OUT, "icon-32.png"), icon32);
writeFileSync(resolve(OUT, "icon-64.png"), icon64);
writeFileSync(resolve(OUT, "icon-192.png"), icon192);
writeFileSync(resolve(OUT, "icon-512.png"), icon512);
writeFileSync(resolve(OUT, "apple-touch-icon.png"), apple);
writeFileSync(resolve(OUT, "icon-maskable-512.png"), maskable);
writeFileSync(resolve(OUT, "favicon.ico"), ico);

const embed = icon64.toString("base64");
const svg = [
  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">',
  "<title>Micabo</title>",
  '<defs><clipPath id="r"><rect width="64" height="64" rx="14" ry="14"/></clipPath></defs>',
  `<image href="data:image/png;base64,${embed}" width="64" height="64" clip-path="url(#r)" />`,
  "</svg>",
  "",
].join("");
writeFileSync(resolve(OUT, "icon.svg"), svg);

for (const name of [
  "icon.png",
  "icon-32.png",
  "icon-64.png",
  "icon-192.png",
  "icon-512.png",
  "apple-touch-icon.png",
  "icon-maskable-512.png",
  "favicon.ico",
  "icon.svg",
]) {
  const { statSync } = await import("node:fs");
  const bytes = statSync(resolve(OUT, name)).size;
  console.log(`${name.padEnd(24)} ${(bytes / 1024).toFixed(1)} KB`);
}
