/**
 * Extraire le texte d'un `.docx`, comme `DocxImportService` sur iOS.
 *
 * Un Word est un ZIP dont `word/document.xml` porte le corps. On le lit ici, dans
 * l'onglet : le serveur ne reçoit que le texte, jamais le fichier.
 */

export class DocxError extends Error {
  constructor(readonly code: "notDocx" | "missingDocument" | "empty") {
    super(code);
  }
}

export async function extractDocxText(bytes: Uint8Array): Promise<string> {
  if (!looksLikeZip(bytes)) throw new DocxError("notDocx");

  const xml = await zipEntry(bytes, "word/document.xml");
  if (!xml) throw new DocxError("missingDocument");

  const text = normalize(wordXmlToText(new TextDecoder("utf-8").decode(xml)));
  if (text.length < 20) throw new DocxError("empty");
  return text;
}

export function wordXmlToText(xml: string): string {
  const parts: string[] = [];
  // `w:t` est la forme Word ; LibreOffice et certains exports omettent le préfixe.
  const tag = /<\/?(?:[a-zA-Z0-9]+:)?([a-zA-Z]+)([^>]*)\/?>/g;
  let last = 0;
  let capture = false;
  let match: RegExpExecArray | null;

  while ((match = tag.exec(xml))) {
    if (capture) parts.push(decodeEntities(xml.slice(last, match.index)));
    last = match.index + match[0].length;

    const name = match[1];
    const selfClosing = match[0].endsWith("/>");

    if (name === "t" && !selfClosing) capture = true;
    else if (name === "t") capture = false;
    else if (name === "tab") parts.push("\t");
    else if (name === "br" || name === "cr") parts.push("\n");
    else if (name === "p" && match[0].startsWith("</")) parts.push("\n");

    if (name === "t" && match[0].startsWith("</")) capture = false;
  }

  return parts.join("");
}

export function looksLikeZip(data: Uint8Array): boolean {
  if (data.length < 4) return false;
  const signature = u32(data, 0);
  return signature === 0x04034b50 || signature === 0x06054b50 || signature === 0x08074b50;
}

async function zipEntry(archive: Uint8Array, path: string): Promise<Uint8Array | null> {
  const eocd = endOfCentralDirectory(archive);
  if (!eocd) return null;

  let cursor = eocd.offset;
  for (let index = 0; index < eocd.count; index += 1) {
    if (cursor + 46 > archive.length || u32(archive, cursor) !== 0x02014b50) return null;
    const compression = u16(archive, cursor + 10);
    const compressed = u32(archive, cursor + 20);
    const nameLength = u16(archive, cursor + 28);
    const extraLength = u16(archive, cursor + 30);
    const commentLength = u16(archive, cursor + 32);
    const localOffset = u32(archive, cursor + 42);
    const nameStart = cursor + 46;
    const name = new TextDecoder("utf-8").decode(archive.subarray(nameStart, nameStart + nameLength));
    cursor = nameStart + nameLength + extraLength + commentLength;

    if (!sameZipPath(name, path)) continue;

    const header = localOffset;
    if (header + 30 > archive.length || u32(archive, header) !== 0x04034b50) return null;
    const localName = u16(archive, header + 26);
    const localExtra = u16(archive, header + 28);
    const payloadStart = header + 30 + localName + localExtra;
    const payload = archive.subarray(payloadStart, payloadStart + compressed);

    if (compression === 0) return payload;
    if (compression === 8) return inflateRaw(payload);
    return null;
  }

  return null;
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

function normalize(text: string): string {
  return text.replace(/\u00a0/g, " ").replace(/[ \t]+\n/g, "\n").replace(/\n{3,}/g, "\n\n").trim();
}

function sameZipPath(name: string, path: string): boolean {
  const left = name.replace(/\\/g, "/").toLowerCase();
  const right = path.replace(/\\/g, "/").toLowerCase();
  return left === right || left.endsWith(`/${right}`);
}

function decodeEntities(value: string): string {
  return value
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'");
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
