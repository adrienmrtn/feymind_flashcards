/**
 * Lire une archive ZIP dans l'onglet, sans dépendance.
 *
 * Deux formats du produit sont des ZIP : un `.docx`, dont on veut une entrée connue
 * (`word/document.xml`), et un `.apkg` d'Anki, dont on cherche celle qui porte la collection
 * sans savoir laquelle des trois c'est. D'où les deux fonctions : une par chemin, une par
 * prédicat.
 *
 * `DEFLATE` est décompressé par `DecompressionStream`, présent partout depuis longtemps, et
 * par `node:zlib` sous les tests. Rien d'autre n'est supporté : les archives que produisent
 * Word et Anki n'utilisent que « stocké » et « dégonflé ».
 */

export interface ZipEntry {
  name: string;
  compression: number;
  compressedSize: number;
  localOffset: number;
}

export function looksLikeZip(data: Uint8Array): boolean {
  if (data.length < 4) return false;
  const signature = u32(data, 0);
  return signature === 0x04034b50 || signature === 0x06054b50 || signature === 0x08074b50;
}

/** Le catalogue central, dans l'ordre où l'archive le déclare. */
export function zipEntries(archive: Uint8Array): ZipEntry[] {
  const eocd = endOfCentralDirectory(archive);
  if (!eocd) return [];

  const entries: ZipEntry[] = [];
  let cursor = eocd.offset;

  for (let index = 0; index < eocd.count; index += 1) {
    if (cursor + 46 > archive.length || u32(archive, cursor) !== 0x02014b50) break;
    const compression = u16(archive, cursor + 10);
    const compressedSize = u32(archive, cursor + 20);
    const nameLength = u16(archive, cursor + 28);
    const extraLength = u16(archive, cursor + 30);
    const commentLength = u16(archive, cursor + 32);
    const localOffset = u32(archive, cursor + 42);
    const nameStart = cursor + 46;

    entries.push({
      name: new TextDecoder("utf-8").decode(archive.subarray(nameStart, nameStart + nameLength)),
      compression,
      compressedSize,
      localOffset,
    });

    cursor = nameStart + nameLength + extraLength + commentLength;
  }

  return entries;
}

/** Le contenu d'une entrée déjà repérée dans le catalogue. */
export async function readZipEntry(
  archive: Uint8Array,
  entry: ZipEntry,
): Promise<Uint8Array | null> {
  const header = entry.localOffset;
  if (header + 30 > archive.length || u32(archive, header) !== 0x04034b50) return null;
  const localName = u16(archive, header + 26);
  const localExtra = u16(archive, header + 28);
  const start = header + 30 + localName + localExtra;
  const payload = archive.subarray(start, start + entry.compressedSize);

  if (entry.compression === 0) return payload;
  if (entry.compression === 8) return inflateRaw(payload);
  return null;
}

/** Une entrée par son chemin, comparé sans la casse et sans le dossier de tête. */
export async function zipEntryAt(archive: Uint8Array, path: string): Promise<Uint8Array | null> {
  const entry = zipEntries(archive).find((candidate) => sameZipPath(candidate.name, path));
  return entry ? readZipEntry(archive, entry) : null;
}

async function inflateRaw(data: Uint8Array): Promise<Uint8Array> {
  if (typeof DecompressionStream !== "undefined") {
    try {
      return await decompress(data, "deflate-raw");
    } catch {
      try {
        return await decompress(data, "deflate");
      } catch {
        const wrapped = new Uint8Array(data.length + 2);
        wrapped[0] = 0x78;
        wrapped[1] = 0x9c;
        wrapped.set(data, 2);
        return await decompress(wrapped, "deflate");
      }
    }
  }

  const zlib = await import("node:zlib");
  try {
    return new Uint8Array(zlib.inflateRawSync(data));
  } catch {
    return new Uint8Array(zlib.inflateSync(data));
  }
}

async function decompress(data: Uint8Array, format: CompressionFormat): Promise<Uint8Array> {
  const stream = new Blob([data as BlobPart]).stream().pipeThrough(new DecompressionStream(format));
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

function endOfCentralDirectory(data: Uint8Array): { count: number; offset: number } | null {
  const minimum = 22;
  if (data.length < minimum) return null;
  const maxComment = Math.min(65_535, data.length - minimum);
  for (let comment = 0; comment <= maxComment; comment += 1) {
    const start = data.length - minimum - comment;
    if (u32(data, start) === 0x06054b50) {
      return { count: u16(data, start + 10), offset: u32(data, start + 16) };
    }
  }
  return null;
}

function sameZipPath(name: string, path: string): boolean {
  const left = name.replace(/\\/g, "/").toLowerCase();
  const right = path.replace(/\\/g, "/").toLowerCase();
  return left === right || left.endsWith(`/${right}`);
}

function u16(data: Uint8Array, offset: number): number {
  return data[offset]! | (data[offset + 1]! << 8);
}

function u32(data: Uint8Array, offset: number): number {
  return (
    (data[offset]! |
      (data[offset + 1]! << 8) |
      (data[offset + 2]! << 16) |
      (data[offset + 3]! << 24)) >>>
    0
  );
}
