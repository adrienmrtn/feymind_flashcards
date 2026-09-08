/**
 * Recadre les figures d'une fiche à partir des pages JPEG de l'import.
 *
 * L'iPhone le fait toujours en local (`CourseSheet.attachingFigureImages`). Le site
 * comptait sur la fonction Edge, puis **renormalisait** la fiche : un schéma un peu
 * lourd passait le premier filet et disparaissait au second. La légende restait,
 * l'image non. Ici, comme sur l'iPhone, on recoupe après coup, avec les pages qu'on
 * a encore en main.
 */

import type { SheetBlock, SheetCrop } from "@micabo/core";

const MAX_FIGURE_WIDTH = 640;
const JPEG_QUALITY = 62;

type Raster = {
  width: number;
  height: number;
  clone: () => Raster;
  crop: (x: number, y: number, w: number, h: number) => Raster;
  resize: (w: number, h: number) => Raster;
  encodeJPEG: (quality: number) => Promise<Uint8Array>;
};

type ImageCtor = { decode: (bytes: Uint8Array) => Promise<Raster> };

function decodeDataUrl(url: string): Uint8Array | null {
  const match = url.trim().match(/^data:image\/[a-zA-Z0-9.+-]+;base64,(.+)$/);
  if (!match?.[1]) return null;
  try {
    return Uint8Array.from(Buffer.from(match[1], "base64"));
  } catch {
    return null;
  }
}

function encodeJpegDataUrl(bytes: Uint8Array): string {
  return `data:image/jpeg;base64,${Buffer.from(bytes).toString("base64")}`;
}

function cropBox(image: Raster, crop: SheetCrop | undefined) {
  const box = crop ?? { x: 0, y: 0, w: 1, h: 1 };
  const left = Math.round(box.x * image.width);
  const top = Math.round(box.y * image.height);
  const width = Math.max(8, Math.round(box.w * image.width));
  const height = Math.max(8, Math.round(box.h * image.height));
  return {
    left: Math.min(left, image.width - 8),
    top: Math.min(top, image.height - 8),
    width: Math.min(width, image.width - left),
    height: Math.min(height, image.height - top),
  };
}

/**
 * Colle une image dans chaque bloc figure qui n'en a pas encore.
 *
 * Sans pages, ou si le recadrage lâche, on laisse le bloc : la légende vaut
 * mieux qu'une fiche refusée. Mais dès qu'une page est là, on recoupe.
 */
export async function attachFigureImages(
  blocks: SheetBlock[],
  images: string[],
): Promise<SheetBlock[]> {
  const needed = blocks.some((block) => block.type === "figure" && !block.image && block.page);
  if (!needed || images.length === 0) return blocks;

  let Image: ImageCtor;
  try {
    const loaded = (await import("imagescript")) as { Image: ImageCtor };
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
      const box = cropBox(image, block.crop);
      const clipped = image.clone().crop(box.left, box.top, box.width, box.height);
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
