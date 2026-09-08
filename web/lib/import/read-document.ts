/**
 * Lire un document déposé, **dans l'onglet**, et nommer précisément ce qui a raté.
 *
 * Ce code vivait dans `ImportPanel`, où toute panne finissait sur la même phrase :
 * « ce fichier n'a pas pu être lu ». Un PDF verrouillé, un fichier resté dans
 * iCloud, un `.pptx` glissé dans la zone de dépôt et un moteur qui n'a pas fini
 * de se charger donnaient le même écran, donc la même impasse : ni la personne
 * ni nous ne pouvions savoir lequel des quatre c'était.
 *
 * D'où ce module. Il rend soit un document, soit un `ReadFailure` **avec un code**,
 * et l'écran choisit la phrase. La classification est pure, donc essayable sans
 * navigateur : c'est elle qui portait le bug, pas l'extraction.
 *
 * Deux gardes valent d'être signalées :
 *
 * - **Le binaire n'est pas du texte.** Un `.pptx` ou une photo tombaient dans la
 *   branche « lis-le comme du texte » et en ressortaient en mojibake : l'import
 *   réussissait, et le modèle recevait des octets de ZIP en guise de cours. Une
 *   fiche facturée pour rien.
 * - **Une page qui refuse ne perd pas le document.** Le rendu des figures et le
 *   texte d'une page sont tentés page par page ; ce qui a été lu est gardé.
 */

import type { PDFPageProxy } from "pdfjs-dist";

import { DocxError, extractDocxText } from "./docx";
import { looksLikeZip, zipEntries } from "./zip";

export type DocumentKind = "pdf" | "docx" | "text";

export interface ReadDocument {
  text: string;
  images: string[];
  kind: DocumentKind;
}

export type ReadFailureCode =
  /** Un format qu'on ne sait pas ouvrir : diapositive, tableur, image, archive. */
  | "unsupported"
  /** L'ancien `.doc` binaire, qui n'est pas un `.docx`. */
  | "legacyWord"
  /** Les octets sont hors de portée : fichier resté dans le nuage, ou déplacé depuis. */
  | "unreachable"
  /** PDF protégé par mot de passe. */
  | "locked"
  /** PDF dont la structure est cassée ou tronquée. */
  | "damaged"
  /** Le moteur de lecture n'a pas pu être chargé. */
  | "engine"
  /** Word lisible, mais presque vide. */
  | "wordEmpty"
  /** Word dont le corps est introuvable. */
  | "wordUnreadable"
  /** Rien d'exploitable : ni texte, ni page à regarder. */
  | "empty"
  /** Tout le reste, et on dit lequel. */
  | "unknown";

export class ReadFailure extends Error {
  constructor(
    readonly code: ReadFailureCode,
    /** Ce qu'a dit la couche du dessous, pour que le message reste diagnostiquable. */
    readonly detail?: string,
  ) {
    super(detail ? `${code}: ${detail}` : code);
    this.name = "ReadFailure";
  }
}

/** Extensions qu'on lit vraiment. */
const PDF_EXTENSIONS = [".pdf"];
const WORD_EXTENSIONS = [".docx"];
const TEXT_EXTENSIONS = [".txt", ".md", ".markdown", ".text"];

/**
 * Formats qu'on refuse **par leur nom**, avant même de lire les octets.
 *
 * Les nommer sert à répondre « exportez-le en PDF » au lieu de « illisible ».
 * Ce sont les fichiers qu'on voit arriver dans la zone de dépôt : un cours est
 * souvent un jeu de diapositives, et une photo de tableau est un réflexe.
 */
const REFUSED_EXTENSIONS = [
  ".ppt", ".pptx", ".odp", ".key",
  ".xls", ".xlsx", ".ods", ".numbers", ".csv",
  ".odt", ".rtf", ".pages", ".epub", ".mobi", ".azw3",
  ".png", ".jpg", ".jpeg", ".gif", ".webp", ".heic", ".heif", ".tif", ".tiff", ".bmp", ".svg",
  ".zip", ".rar", ".7z", ".tar", ".gz",
  ".mp3", ".mp4", ".mov", ".m4a", ".wav", ".avi", ".mkv",
];

function endsWithOneOf(name: string, extensions: string[]): boolean {
  return extensions.some((extension) => name.endsWith(extension));
}

/**
 * Ce qu'on va tenter, d'après le nom seul.
 *
 * `null` ne veut pas dire « refusé » : un `.tex`, un `.org` ou un fichier sans
 * extension restent souvent du texte. On tentera la lecture, et c'est
 * `looksBinary` qui tranchera.
 */
export function documentKind(fileName: string): DocumentKind | null {
  const name = fileName.toLowerCase();
  if (endsWithOneOf(name, PDF_EXTENSIONS)) return "pdf";
  if (endsWithOneOf(name, WORD_EXTENSIONS)) return "docx";
  if (endsWithOneOf(name, TEXT_EXTENSIONS)) return "text";
  return null;
}

/**
 * Ce que disent les octets, quand le nom se tait ou se trompe.
 *
 * Le sélecteur de fichiers de l'iPhone ne garantit pas l'extension, et c'est là que le nom
 * seul devenait un piège : un PDF arrivait dans la branche « lis-le comme du texte », en
 * ressortait en mojibake, et se faisait refuser comme un format inconnu. `null` veut dire
 * « les octets ne tranchent pas » : au nom de décider.
 */
export function sniffKind(
  data: Uint8Array,
): "pdf" | "docx" | "image" | "legacyWord" | null {
  if (hasPdfHeader(data)) return "pdf";
  if (looksLikeZip(data) && holdsWordDocument(data)) return "docx";
  if (startsWith(data, [0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1])) return "legacyWord";
  if (isImage(data)) return "image";
  return null;
}

/** `%PDF` ouvre le fichier ; quelques exports le font précéder de deux ou trois octets. */
function hasPdfHeader(data: Uint8Array): boolean {
  const head = data.subarray(0, 1_024);
  for (let index = 0; index + 4 <= head.length; index += 1) {
    if (head[index] === 0x25 && head[index + 1] === 0x50 && head[index + 2] === 0x44 && head[index + 3] === 0x46) {
      return true;
    }
  }
  return false;
}

/** Un `.docx` est un ZIP qui déclare `word/document.xml` ; un `.apkg` ou un `.xlsx` non. */
function holdsWordDocument(data: Uint8Array): boolean {
  return zipEntries(data).some((entry) => {
    const path = entry.name.replace(/\\/g, "/").toLowerCase();
    return path === "word/document.xml" || path.endsWith("/word/document.xml");
  });
}

/** Une photo, pas un document : JPEG, PNG, GIF, WebP, TIFF, et le HEIC de l'iPhone. */
function isImage(data: Uint8Array): boolean {
  if (startsWith(data, [0xff, 0xd8, 0xff])) return true;
  if (startsWith(data, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) return true;
  if (hasTag(data, 0, "GIF8")) return true;
  if (hasTag(data, 0, "RIFF") && hasTag(data, 8, "WEBP")) return true;
  if (startsWith(data, [0x49, 0x49, 0x2a, 0x00]) || startsWith(data, [0x4d, 0x4d, 0x00, 0x2a])) return true;
  if (hasTag(data, 4, "ftyp")) {
    const brand = String.fromCharCode(...data.subarray(8, 12));
    return ["heic", "heix", "hevc", "heim", "heis", "hevm", "mif1", "msf1", "avif"].includes(brand);
  }
  return false;
}

function startsWith(data: Uint8Array, signature: number[]): boolean {
  return signature.every((byte, index) => data[index] === byte);
}

function hasTag(data: Uint8Array, offset: number, tag: string): boolean {
  return [...tag].every((character, index) => data[offset + index] === character.charCodeAt(0));
}

/**
 * Décoder un fichier texte, en respectant sa marque d'ordre et l'UTF-16 sans marque.
 *
 * Un export « texte brut » de Word part souvent en UTF-16 : un octet nul sur deux. Décodé
 * en UTF-8 il ne reste qu'une suite de caractères de remplacement, que `looksBinary` refuse
 * — à raison, mais le fichier, lui, était lisible.
 */
export function decodeText(data: Uint8Array): string {
  const { label, skip } = textEncodingOf(data);
  return new TextDecoder(label).decode(data.subarray(skip)).replace(/\r\n?/g, "\n");
}

function textEncodingOf(data: Uint8Array): { label: string; skip: number } {
  if (data[0] === 0xef && data[1] === 0xbb && data[2] === 0xbf) return { label: "utf-8", skip: 3 };
  if (data[0] === 0xff && data[1] === 0xfe) return { label: "utf-16le", skip: 2 };
  if (data[0] === 0xfe && data[1] === 0xff) return { label: "utf-16be", skip: 2 };

  const head = data.subarray(0, 512);
  let evenNulls = 0;
  let oddNulls = 0;
  for (let index = 0; index < head.length; index += 1) {
    if (head[index] !== 0) continue;
    if (index % 2 === 0) evenNulls += 1;
    else oddNulls += 1;
  }
  const pairs = Math.floor(head.length / 2);
  if (pairs > 8 && oddNulls > pairs * 0.4 && evenNulls === 0) return { label: "utf-16le", skip: 0 };
  if (pairs > 8 && evenNulls > pairs * 0.4 && oddNulls === 0) return { label: "utf-16be", skip: 0 };

  return { label: "utf-8", skip: 0 };
}

/** Un format nommément refusé, ou l'ancien Word. */
export function refusedKind(fileName: string): "unsupported" | "legacyWord" | null {
  const name = fileName.toLowerCase();
  if (name.endsWith(".doc")) return "legacyWord";
  if (endsWithOneOf(name, REFUSED_EXTENSIONS)) return "unsupported";
  return null;
}

/**
 * Est-ce que ce « texte » est en réalité des octets ?
 *
 * `File.text()` ne refuse jamais : il décode en UTF-8 et remplace ce qu'il ne
 * comprend pas par U+FFFD. Un ZIP en ressort donc comme une chaîne bien formée,
 * assez longue pour passer le seuil des 40 caractères. On regarde donc ce que
 * contient la chaîne, pas si on a réussi à en faire une.
 */
export function looksBinary(text: string): boolean {
  if (text.length === 0) return false;
  const sample = text.slice(0, 4_000);

  let replacement = 0;
  let control = 0;
  for (const character of sample) {
    const code = character.codePointAt(0) ?? 0;
    if (code === 0) return true;
    if (code === 0xfffd) replacement += 1;
    else if (code < 0x20 && code !== 9 && code !== 10 && code !== 13) control += 1;
  }

  return (replacement + control) / sample.length > 0.02;
}

/**
 * Traduire une panne de la couche du dessous en code.
 *
 * pdf.js signe ses erreurs par `name` (`PasswordException`, `InvalidPDFException`,
 * …) et non par des classes qu'on pourrait tester : c'est donc `name` qu'on lit.
 * Le navigateur, lui, lève une `DOMException` quand les octets d'un `File` ne
 * sont plus là - un fichier encore dans iCloud ou OneDrive, ou déplacé entre le
 * choix et la lecture. C'est cette panne-là qui se présentait comme « illisible »
 * alors que le fichier était simplement à télécharger.
 */
export function classifyReadFailure(error: unknown): ReadFailureCode {
  if (error instanceof ReadFailure) return error.code;

  if (error instanceof DocxError) {
    if (error.code === "empty") return "wordEmpty";
    if (error.code === "missingDocument") return "wordUnreadable";
    return "unsupported";
  }

  const name = error instanceof Error ? error.name : "";
  const message = error instanceof Error ? error.message : String(error ?? "");

  if (name === "PasswordException") return "locked";
  if (name === "InvalidPDFException") return "damaged";
  if (name === "MissingPDFException" || name === "UnexpectedResponseException") return "unreachable";

  if (name === "NotReadableError" || name === "NotFoundError") return "unreachable";
  if (name === "SecurityError" || name === "NotAllowedError") return "unreachable";

  // Le module de lecture arrive en morceau séparé : hors ligne, ou après un
  // déploiement dans un onglet resté ouvert, c'est son chargement qui lâche.
  if (
    /dynamically imported module|Loading chunk|ChunkLoadError|Importing a module script failed|error loading dynamically imported module/i
      .test(message)
  ) {
    return "engine";
  }

  return "unknown";
}

/** De quoi écrire un rapport utile quand il ne reste que « inconnu ». */
export function failureDetail(error: unknown): string | undefined {
  if (error instanceof ReadFailure) return error.detail;
  if (error instanceof Error) {
    const name = error.name && error.name !== "Error" ? error.name : "";
    const message = error.message?.slice(0, 160) ?? "";
    return [name, message].filter(Boolean).join(": ") || undefined;
  }
  const text = String(error ?? "").slice(0, 160);
  return text || undefined;
}

/** Combien de pages on rend en image, pour en extraire les schémas. */
const IMAGE_PAGE_LIMIT = 4;

/** En dessous, il n'y a pas de cours à ficher. */
export const MIN_TEXT_LENGTH = 40;

/**
 * Lire le fichier, ou lever un `ReadFailure`.
 *
 * `loadPdfEngine` est injectable pour les essais ; en vrai c'est pdf.js, chargé
 * à la demande avec son worker empaqueté par le bundler - une URL du site, pas
 * un CDN : le worker d'un tiers est une panne de plus, et une origine de plus.
 */
export async function readDocument(
  file: File,
  loadPdfEngine: () => Promise<PdfEngine> = loadBundledPdfEngine,
): Promise<ReadDocument> {
  const refused = refusedKind(file.name);
  if (refused) throw new ReadFailure(refused, extensionOf(file.name));

  const data = await bytes(file);
  // Les octets ont le dernier mot sur le nom : un document qui sort du sélecteur de
  // l'iPhone n'arrive pas toujours avec son extension, et un PDF sans « .pdf » finissait
  // décodé comme du texte, puis refusé comme un binaire.
  const sniffed = sniffKind(new Uint8Array(data));
  if (sniffed === "image") throw new ReadFailure("unsupported", extensionOf(file.name) ?? "image");
  if (sniffed === "legacyWord") throw new ReadFailure("legacyWord", extensionOf(file.name));

  const kind = sniffed ?? documentKind(file.name);

  if (kind === "pdf") return readPdf(data, await pdfEngine(loadPdfEngine));
  if (kind === "docx") return { ...(await readWord(new Uint8Array(data))), kind: "docx" };

  const text = decodeText(new Uint8Array(data));
  // Sans extension connue, c'est le contenu qui décide. Un ZIP déguisé s'arrête ici.
  if (looksBinary(text)) throw new ReadFailure("unsupported", extensionOf(file.name));
  return { text, images: [], kind: "text" };
}

function extensionOf(fileName: string): string | undefined {
  const parts = fileName.split(".");
  return parts.length > 1 ? parts.pop() : undefined;
}

/** Le contrat minimal qu'on attend de pdf.js, pour pouvoir le remplacer en essai. */
export interface PdfEngine {
  getDocument(source: { data: ArrayBuffer }): {
    promise: Promise<{
      numPages: number;
      getPage(index: number): Promise<PDFPageProxy>;
    }>;
  };
}

async function pdfEngine(load: () => Promise<PdfEngine>): Promise<PdfEngine> {
  try {
    return await load();
  } catch (error) {
    throw new ReadFailure("engine", failureDetail(error));
  }
}

async function loadBundledPdfEngine(): Promise<PdfEngine> {
  const pdfjs = await import("pdfjs-dist");
  // Empaqueté avec le site : même origine, même version que la bibliothèque,
  // et rien à charger chez un tiers au moment où quelqu'un dépose un fichier.
  pdfjs.GlobalWorkerOptions.workerSrc = new URL(
    "pdfjs-dist/build/pdf.worker.min.mjs",
    import.meta.url,
  ).toString();
  return pdfjs as unknown as PdfEngine;
}

/**
 * Les octets du fichier, en une seule lecture, et deux chemins pour les obtenir.
 *
 * Safari iOS remet parfois un `File` dont la lecture ne rend rien : un document encore dans
 * iCloud, ou déplacé entre le choix et la lecture. Selon le cas il lève, ou il rend zéro
 * octet sans rien dire - et zéro octet lu n'est pas un fichier vide. `FileReader`, l'autre
 * chemin de lecture du navigateur, aboutit parfois là où `arrayBuffer()` renonce ; sinon on
 * renvoie vers le nuage, ce qui se répare, au lieu d'un « illisible » qui ne dit rien.
 */
async function bytes(file: File): Promise<ArrayBuffer> {
  let direct: ArrayBuffer | null = null;
  try {
    direct = await file.arrayBuffer();
  } catch (error) {
    const retried = await bytesFromFileReader(file);
    if (retried) return retried;
    throw new ReadFailure(classifyReadFailure(error), failureDetail(error));
  }

  if (direct.byteLength > 0) return direct;

  const retried = await bytesFromFileReader(file);
  if (retried) return retried;
  throw new ReadFailure("unreachable");
}

async function bytesFromFileReader(file: File): Promise<ArrayBuffer | null> {
  if (typeof FileReader === "undefined") return null;
  try {
    const buffer = await new Promise<ArrayBuffer | null>((resolve) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result instanceof ArrayBuffer ? reader.result : null);
      reader.onerror = () => resolve(null);
      reader.readAsArrayBuffer(file);
    });
    return buffer && buffer.byteLength > 0 ? buffer : null;
  } catch {
    return null;
  }
}

async function readWord(data: Uint8Array): Promise<{ text: string; images: string[] }> {
  try {
    return { text: await extractDocxText(data), images: [] };
  } catch (error) {
    throw new ReadFailure(classifyReadFailure(error), failureDetail(error));
  }
}

async function readPdf(data: ArrayBuffer, engine: PdfEngine): Promise<ReadDocument> {
  let pdf: { numPages: number; getPage(index: number): Promise<PDFPageProxy> };
  try {
    pdf = await engine.getDocument({ data }).promise;
  } catch (error) {
    throw new ReadFailure(classifyReadFailure(error), failureDetail(error));
  }

  const pages: string[] = [];
  const images: string[] = [];
  const imageLimit = Math.min(pdf.numPages, IMAGE_PAGE_LIMIT);
  let refusal: unknown = null;
  let readPages = 0;

  for (let index = 1; index <= pdf.numPages; index += 1) {
    // Une page qui refuse est une page perdue, pas un document perdu : un PDF de
    // cinquante pages dont la douzième porte une police cassée reste fichable. Le texte
    // et l'image se tentent séparément : un scan sans texte garde son image, et une page
    // qui ne se dessine pas garde son texte.
    let page: PDFPageProxy;
    try {
      page = await pdf.getPage(index);
    } catch (error) {
      refusal ??= error;
      continue;
    }

    try {
      pages.push(await pageText(page));
      readPages += 1;
    } catch (error) {
      refusal ??= error;
    }

    if (index <= imageLimit) {
      try {
        const rendered = await renderPdfPage(page);
        if (rendered) images.push(rendered);
      } catch (error) {
        refusal ??= error;
      }
    }
  }

  const text = pages.filter(Boolean).join("\n\n");
  if (text.trim().length === 0 && images.length === 0) {
    // « Pas de texte » est une conclusion sur le document, et elle ne vaut que si on a
    // réussi à le lire. Aucune page lue et une panne en réserve : c'est la lecture qu'il
    // faut nommer, sinon un défaut de notre côté se déguise en PDF scanné.
    if (readPages === 0 && refusal !== null) {
      throw new ReadFailure(classifyReadFailure(refusal), failureDetail(refusal));
    }
    throw new ReadFailure("empty");
  }

  return { text, images, kind: "pdf" };
}

/**
 * Le texte d'une page, lu par le `reader` du flux et **jamais** par
 * `page.getTextContent()`.
 *
 * Cette méthode de pdf.js parcourt son flux avec `for await`, et WebKit n'expose pas
 * `Symbol.asyncIterator` sur un `ReadableStream` : aucun Safari livré ne sait faire cette
 * boucle. Sur le site ouvert à l'iPhone, la première page levait « iterable should have an
 * iterator symbol », chaque page était donc perdue, et l'écran concluait que le document
 * n'avait pas de texte. Le même flux, lu par son `reader`, marche partout.
 */
async function pageText(page: PdfTextSource): Promise<string> {
  const chunks = page.streamTextContent
    ? await collectChunks(page.streamTextContent().getReader())
    : page.getTextContent
      ? [await page.getTextContent()]
      : [];

  return chunks
    .flatMap((chunk) => (chunk.items ?? []).map(itemText))
    .join(" ")
    .replace(/\s+/g, " ")
    .trim();
}

interface PdfTextChunk {
  items?: readonly unknown[];
}

interface PdfTextReader {
  read: () => Promise<{ done: boolean; value?: PdfTextChunk }>;
  releaseLock: () => void;
}

/** De la page, on ne prend que le texte : d'où ce contrat, plus étroit que pdf.js. */
interface PdfTextSource {
  streamTextContent?: () => { getReader: () => PdfTextReader };
  getTextContent?: () => Promise<PdfTextChunk>;
}

async function collectChunks(reader: PdfTextReader): Promise<PdfTextChunk[]> {
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

function itemText(item: unknown): string {
  if (!item || typeof item !== "object" || !("str" in item)) return "";
  const value = (item as { str: unknown }).str;
  return typeof value === "string" ? value : "";
}

async function renderPdfPage(page: PDFPageProxy): Promise<string | null> {
  const viewport = page.getViewport({ scale: 1.1 });
  const canvas = document.createElement("canvas");
  canvas.width = Math.max(1, Math.round(viewport.width));
  canvas.height = Math.max(1, Math.round(viewport.height));
  const context = canvas.getContext("2d");
  if (!context) return null;
  await page.render({ canvas, canvasContext: context, viewport }).promise;
  const url = canvas.toDataURL("image/jpeg", 0.5);
  return url.startsWith("data:image/") ? url : null;
}
