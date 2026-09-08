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
  if (refused) throw new ReadFailure(refused, file.name.split(".").pop());

  const kind = documentKind(file.name);

  if (kind === "pdf") return readPdf(file, await pdfEngine(loadPdfEngine));
  if (kind === "docx") return { ...(await readWord(file)), kind: "docx" };

  const text = await readText(file);
  // Sans extension connue, c'est le contenu qui décide. Un ZIP déguisé s'arrête ici.
  if (looksBinary(text)) throw new ReadFailure("unsupported", file.name.split(".").pop());
  return { text, images: [], kind: "text" };
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

async function bytes(file: File): Promise<ArrayBuffer> {
  try {
    return await file.arrayBuffer();
  } catch (error) {
    throw new ReadFailure(classifyReadFailure(error), failureDetail(error));
  }
}

async function readText(file: File): Promise<string> {
  try {
    return await file.text();
  } catch (error) {
    throw new ReadFailure(classifyReadFailure(error), failureDetail(error));
  }
}

async function readWord(file: File): Promise<{ text: string; images: string[] }> {
  const data = new Uint8Array(await bytes(file));
  try {
    return { text: await extractDocxText(data), images: [] };
  } catch (error) {
    throw new ReadFailure(classifyReadFailure(error), failureDetail(error));
  }
}

async function readPdf(file: File, engine: PdfEngine): Promise<ReadDocument> {
  const data = await bytes(file);

  let pdf: { numPages: number; getPage(index: number): Promise<PDFPageProxy> };
  try {
    pdf = await engine.getDocument({ data }).promise;
  } catch (error) {
    throw new ReadFailure(classifyReadFailure(error), failureDetail(error));
  }

  const pages: string[] = [];
  const images: string[] = [];
  const imageLimit = Math.min(pdf.numPages, IMAGE_PAGE_LIMIT);

  for (let index = 1; index <= pdf.numPages; index += 1) {
    // Une page qui refuse est une page perdue, pas un document perdu : un PDF de
    // cinquante pages dont la douzième porte une police cassée reste fichable.
    try {
      const page = await pdf.getPage(index);
      pages.push(pageText(await page.getTextContent()));

      if (index <= imageLimit) {
        const rendered = await renderPdfPage(page);
        if (rendered) images.push(rendered);
      }
    } catch {
      continue;
    }
  }

  const text = pages.filter(Boolean).join("\n\n");
  if (text.trim().length === 0 && images.length === 0) {
    throw new ReadFailure("empty");
  }

  return { text, images, kind: "pdf" };
}

function pageText(content: { items: unknown[] }): string {
  return content.items
    .map((item) => (item && typeof item === "object" && "str" in item ? String(item.str) : ""))
    .join(" ")
    .replace(/\s+/g, " ")
    .trim();
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
