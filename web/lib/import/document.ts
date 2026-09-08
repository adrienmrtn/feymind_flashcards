/**
 * Lire un document déposé dans l'onglet : ses octets, sa nature, son texte.
 *
 * **Ce fichier existe pour Safari de l'iPhone.** Le même import marchait sur un
 * ordinateur et dans l'app, et échouait sur le site ouvert au téléphone, sur
 * chaque document. Trois détours sont pris ici, et chacun se vérifie sans
 * navigateur, sous vitest :
 *
 * 1. **Le texte d'une page de PDF se lit par `getReader()`**, pas par
 *    `page.getTextContent()`. Cette méthode de pdf.js parcourt son flux avec
 *    `for await`, et WebKit n'expose pas `Symbol.asyncIterator` sur un
 *    `ReadableStream` : sur iPhone, la première page levait
 *    « iterable should have an iterator symbol » et l'import s'arrêtait là. Le
 *    même flux, lu par son `reader`, marche partout.
 *
 * 2. **La nature du fichier se reconnaît à ses octets**, pas à son nom. Un
 *    document qui passe par le sélecteur de l'iPhone n'arrive pas toujours avec
 *    son extension : un PDF sans « .pdf » finissait décodé comme du texte, et
 *    « ce fichier ne contient pas de texte lisible » était le seul indice.
 *
 * 3. **Les octets sont relus par `FileReader`** si `arrayBuffer()` n'en rend
 *    aucun. Safari iOS remet parfois un fichier iCloud qui n'est pas encore
 *    descendu sur l'appareil : le `File` existe, sa lecture est vide. Quand les
 *    deux lectures sont vides, on le dit — plutôt que d'accuser le document de
 *    n'avoir pas de texte.
 */

import { looksLikeZip, zipEntries } from "./zip";

export type DocumentKind = "pdf" | "docx" | "legacyDoc" | "text";

/** Le fichier est arrivé vide : ni `arrayBuffer()` ni `FileReader` n'en tirent d'octets. */
export class EmptyFileError extends Error {
  constructor() {
    super("empty");
  }
}

export async function readFileBytes(file: Blob): Promise<Uint8Array> {
  const direct = await bytesFromArrayBuffer(file);
  if (direct) return direct;

  const buffered = await bytesFromFileReader(file);
  if (buffered) return buffered;

  throw new EmptyFileError();
}

export function documentKind(bytes: Uint8Array, name = ""): DocumentKind {
  if (hasPdfHeader(bytes)) return "pdf";
  if (looksLikeZip(bytes) && holdsWordDocument(bytes)) return "docx";
  if (isLegacyOfficeFile(bytes)) return "legacyDoc";

  // Les octets n'ont rien dit : un ZIP illisible ou un PDF tronqué garde tout de même
  // son nom, et pdf.js dira mieux que nous ce qui manque dedans.
  const lower = name.toLowerCase();
  if (lower.endsWith(".pdf")) return "pdf";
  if (lower.endsWith(".docx")) return "docx";
  if (lower.endsWith(".doc")) return "legacyDoc";
  return "text";
}

/** Décoder un fichier texte, en respectant sa marque d'ordre et l'UTF-16 sans marque. */
export function decodeDocumentText(bytes: Uint8Array): string {
  const { label, skip } = textEncodingOf(bytes);
  return new TextDecoder(label).decode(bytes.subarray(skip)).replace(/\r\n?/g, "\n");
}

interface PdfTextChunk {
  items?: readonly unknown[];
}

interface PdfTextReader {
  read: () => Promise<{ done: boolean; value?: PdfTextChunk }>;
  releaseLock: () => void;
}

/**
 * La page telle qu'on s'en sert : son flux de texte lu par son `reader`, et la méthode
 * d'ensemble en repli. Un type à nous, et non celui de pdf.js, pour qu'un test décrive une
 * page en trois lignes — et pour ne décrire du flux que ce qu'on en prend.
 */
export interface PdfTextPage {
  streamTextContent?: () => { getReader: () => PdfTextReader };
  getTextContent?: () => Promise<PdfTextChunk>;
}

export async function readPdfPageText(page: PdfTextPage): Promise<string> {
  const chunks = page.streamTextContent
    ? await collectStream(page.streamTextContent().getReader())
    : page.getTextContent
      ? [await page.getTextContent()]
      : [];

  return chunks
    .flatMap((chunk) => (chunk.items ?? []).map(itemText))
    .join(" ")
    .replace(/\s+/g, " ")
    .trim();
}

function itemText(item: unknown): string {
  if (!item || typeof item !== "object" || !("str" in item)) return "";
  const value = (item as { str: unknown }).str;
  return typeof value === "string" ? value : "";
}

async function collectStream(reader: PdfTextReader): Promise<PdfTextChunk[]> {
  const chunks: PdfTextChunk[] = [];
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      if (value) chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  return chunks;
}

async function bytesFromArrayBuffer(file: Blob): Promise<Uint8Array | null> {
  try {
    const buffer = await file.arrayBuffer();
    return buffer.byteLength > 0 ? new Uint8Array(buffer) : null;
  } catch {
    return null;
  }
}

async function bytesFromFileReader(file: Blob): Promise<Uint8Array | null> {
  if (typeof FileReader === "undefined") return null;
  try {
    const buffer = await new Promise<ArrayBuffer | null>((resolve) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result instanceof ArrayBuffer ? reader.result : null);
      reader.onerror = () => resolve(null);
      reader.readAsArrayBuffer(file);
    });
    return buffer && buffer.byteLength > 0 ? new Uint8Array(buffer) : null;
  } catch {
    return null;
  }
}

/** `%PDF` est censé ouvrir le fichier ; certains exports le font précéder de quelques octets. */
function hasPdfHeader(bytes: Uint8Array): boolean {
  const window = bytes.subarray(0, 1_024);
  for (let index = 0; index + 4 <= window.length; index += 1) {
    if (
      window[index] === 0x25 &&
      window[index + 1] === 0x50 &&
      window[index + 2] === 0x44 &&
      window[index + 3] === 0x46
    ) {
      return true;
    }
  }
  return false;
}

/** Un `.docx` est un ZIP qui déclare `word/document.xml` ; un `.apkg` ou un `.xlsx` non. */
function holdsWordDocument(bytes: Uint8Array): boolean {
  return zipEntries(bytes).some((entry) => {
    const path = entry.name.replace(/\\/g, "/").toLowerCase();
    return path === "word/document.xml" || path.endsWith("/word/document.xml");
  });
}

/** La signature OLE2 : un `.doc` d'avant 2007, que le navigateur ne sait pas ouvrir. */
function isLegacyOfficeFile(bytes: Uint8Array): boolean {
  const signature = [0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1];
  return signature.every((byte, index) => bytes[index] === byte);
}

function textEncodingOf(bytes: Uint8Array): { label: string; skip: number } {
  if (bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf) return { label: "utf-8", skip: 3 };
  if (bytes[0] === 0xff && bytes[1] === 0xfe) return { label: "utf-16le", skip: 2 };
  if (bytes[0] === 0xfe && bytes[1] === 0xff) return { label: "utf-16be", skip: 2 };

  // Un export « texte brut » de Word part souvent en UTF-16 sans marque : un octet nul
  // sur deux. Décodé en UTF-8, il ne resterait qu'une suite de caractères de
  // remplacement, assez longue pour passer pour du contenu.
  const window = bytes.subarray(0, 512);
  let evenNulls = 0;
  let oddNulls = 0;
  for (let index = 0; index < window.length; index += 1) {
    if (window[index] !== 0) continue;
    if (index % 2 === 0) evenNulls += 1;
    else oddNulls += 1;
  }
  const half = Math.floor(window.length / 2);
  if (half > 8 && oddNulls > half * 0.4 && evenNulls === 0) return { label: "utf-16le", skip: 0 };
  if (half > 8 && evenNulls > half * 0.4 && oddNulls === 0) return { label: "utf-16be", skip: 0 };

  return { label: "utf-8", skip: 0 };
}
