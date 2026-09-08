/**
 * Les figures recadrées depuis les pages du document.
 *
 * Un schéma généré invente des flèches et des légendes. On coupe donc la figure
 * telle qu'elle est imprimée, et on la pose dans la fiche avec sa légende.
 */

import { SHEET_LIMITS, type SheetBlock, type SheetCrop } from "./sheet.ts";

export interface ExtractedFigure {
  page: number;
  crop: SheetCrop;
  caption: string;
}

const FIGURE_LINE =
  /FIGURE\s+page\s*=\s*(\d+)\s+x\s*=\s*([\d.,]+)\s+y\s*=\s*([\d.,]+)\s+w\s*=\s*([\d.,]+)\s+h\s*=\s*([\d.,]+)\s+caption\s*=\s*(.+)/i;

const MAX_FIGURE_WIDTH = 640;
const JPEG_QUALITY = 62;

function parseNumber(raw: string): number | null {
  const parsed = Number.parseFloat(raw.replace(",", "."));
  return Number.isFinite(parsed) ? parsed : null;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function cropOf(x: number, y: number, w: number, h: number): SheetCrop | null {
  const crop = {
    x: clamp(x, 0, 0.95),
    y: clamp(y, 0, 0.95),
    w: clamp(w, 0.08, 1),
    h: clamp(h, 0.08, 1),
  };
  if (crop.x + crop.w > 1) crop.w = 1 - crop.x;
  if (crop.y + crop.h > 1) crop.h = 1 - crop.y;
  if (crop.w < 0.08 || crop.h < 0.08) return null;
  return crop;
}

/** Relève les lignes FIGURE que la passe visuelle a posées dans sa description. */
export function parseExtractedFigures(notes: string): ExtractedFigure[] {
  const figures: ExtractedFigure[] = [];
  const seen = new Set<string>();

  for (const line of notes.split(/\r?\n/)) {
    const match = line.trim().match(FIGURE_LINE);
    if (!match) continue;

    const page = Number.parseInt(match[1] ?? "", 10);
    const x = parseNumber(match[2] ?? "");
    const y = parseNumber(match[3] ?? "");
    const w = parseNumber(match[4] ?? "");
    const h = parseNumber(match[5] ?? "");
    const caption = (match[6] ?? "").replace(/\s+/g, " ").trim();
    if (!Number.isFinite(page) || page < 1 || x === null || y === null || w === null || h === null) {
      continue;
    }
    if (caption.length < 4) continue;

    const crop = cropOf(x, y, w, h);
    if (!crop) continue;

    const key = `${page}:${caption.toLowerCase()}`;
    if (seen.has(key)) continue;
    seen.add(key);
    figures.push({ page, crop, caption });
    if (figures.length >= SHEET_LIMITS.figureBlocks) break;
  }

  return figures;
}

/** Ce que le rédacteur de la fiche doit savoir des figures déjà trouvées. */
export function figuresBrief(figures: ExtractedFigure[]): string {
  if (figures.length === 0) return "";

  const lines = figures.map((figure, index) => {
    const { x, y, w, h } = figure.crop;
    return `${index + 1}. page=${figure.page} x=${x.toFixed(2)} y=${y.toFixed(2)} w=${w.toFixed(2)} h=${h.toFixed(2)} : ${figure.caption}`;
  });

  return `FIGURES EXTRAITES DU DOCUMENT
Le document porte des figures déjà localisées. Place chacune avec un bloc "figure", au plus près du passage qu'elle illustre. Recopie page et crop tels quels. N'invente aucune autre figure, et n'en omets aucune.
{"type":"figure","page":2,"crop":{"x":0.08,"y":0.12,"w":0.84,"h":0.40},"caption":"Titre court de la figure"}

${lines.join("\n")}`;
}

function figureKey(page: number | undefined, caption: string): string {
  return `${page ?? 0}:${caption.trim().toLowerCase()}`;
}

/**
 * Les figures que le modèle a oublié de placer : on les glisse après le premier
 * paragraphe, plutôt que de les perdre. Une figure extraite et absente de la fiche
 * est plus grave qu'une figure un peu mal placée.
 */
export function injectUnusedFigures(
  blocks: SheetBlock[],
  figures: ExtractedFigure[],
): SheetBlock[] {
  if (figures.length === 0) return blocks;

  const used = new Set(
    blocks
      .filter((block): block is Extract<SheetBlock, { type: "figure" }> => block.type === "figure")
      .map((block) => figureKey(block.page, block.caption)),
  );

  const unused = figures.filter((figure) => !used.has(figureKey(figure.page, figure.caption)));
  if (unused.length === 0) return blocks;

  const already = blocks.filter((block) => block.type === "figure").length;
  const room = Math.max(0, SHEET_LIMITS.figureBlocks - already);
  const incoming = unused.slice(0, room).map((figure) => ({
    type: "figure" as const,
    caption: figure.caption,
    page: figure.page,
    crop: figure.crop,
  }));
  if (incoming.length === 0) return blocks;

  const insertAt = Math.max(
    0,
    blocks.findIndex((block) => block.type === "paragraph") + 1,
  );
  return [...blocks.slice(0, insertAt), ...incoming, ...blocks.slice(insertAt)];
}

function decodeDataUrl(url: string): Uint8Array | null {
  const match = url.trim().match(/^data:image\/[a-zA-Z0-9.+-]+;base64,(.+)$/);
  if (!match?.[1]) return null;
  try {
    const binary = atob(match[1]);
    const bytes = new Uint8Array(binary.length);
    for (let index = 0; index < binary.length; index += 1) {
      bytes[index] = binary.charCodeAt(index);
    }
    return bytes;
  } catch {
    return null;
  }
}

function encodeJpegDataUrl(bytes: Uint8Array): string {
  let binary = "";
  const chunk = 0x8000;
  for (let index = 0; index < bytes.length; index += chunk) {
    binary += String.fromCharCode(...bytes.subarray(index, index + chunk));
  }
  return `data:image/jpeg;base64,${btoa(binary)}`;
}

/**
 * Coupe les JPEG des pages et les colle dans les blocs figure.
 *
 * Sans ça, la fiche ne porterait que des coordonnées : l'iPhone peut recouper
 * localement, le site non, une fois le cours enregistré.
 */
export async function attachFigureImages(
  blocks: SheetBlock[],
  images: string[],
): Promise<SheetBlock[]> {
  const needed = blocks.some((block) => block.type === "figure" && !block.image && block.page);
  if (!needed) return blocks;

  type Raster = {
    width: number;
    height: number;
    clone: () => Raster;
    crop: (x: number, y: number, w: number, h: number) => Raster;
    resize: (w: number, h: number) => Raster;
    encodeJPEG: (quality: number) => Promise<Uint8Array>;
  };
  type ImageCtor = { decode: (bytes: Uint8Array) => Promise<Raster> };

  let Image: ImageCtor;
  try {
    const loaded = await import("npm:imagescript@1.3.0") as { Image: ImageCtor };
    Image = loaded.Image;
  } catch {
    return blocks;
  }

  const decoded = new Map<number, Raster>();

  async function pageImage(page: number) {
    if (decoded.has(page)) return decoded.get(page) ?? null;
    const source = images[page - 1];
    if (!source) return null;
    const bytes = decodeDataUrl(source);
    if (!bytes) return null;
    try {
      const image = await Image.decode(bytes);
      decoded.set(page, image);
      return image;
    } catch {
      return null;
    }
  }

  const next: SheetBlock[] = [];
  for (const block of blocks) {
    if (block.type !== "figure" || block.image || !block.page) {
      next.push(block);
      continue;
    }

    const image = await pageImage(block.page);
    if (!image) {
      next.push(block);
      continue;
    }

    try {
      const crop = block.crop ?? { x: 0, y: 0, w: 1, h: 1 };
      const left = Math.round(crop.x * image.width);
      const top = Math.round(crop.y * image.height);
      const width = Math.max(8, Math.round(crop.w * image.width));
      const height = Math.max(8, Math.round(crop.h * image.height));
      const clipped = image.clone().crop(
        Math.min(left, image.width - 8),
        Math.min(top, image.height - 8),
        Math.min(width, image.width - left),
        Math.min(height, image.height - top),
      );
      if (clipped.width > MAX_FIGURE_WIDTH) {
        const scaled = Math.round(clipped.height * (MAX_FIGURE_WIDTH / clipped.width));
        clipped.resize(MAX_FIGURE_WIDTH, Math.max(1, scaled));
      }
      const jpeg = await clipped.encodeJPEG(JPEG_QUALITY);
      next.push({ ...block, image: encodeJpegDataUrl(jpeg) });
    } catch {
      next.push(block);
    }
  }

  return next;
}
