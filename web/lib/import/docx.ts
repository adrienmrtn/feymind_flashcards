/**
 * Extraire le texte d'un `.docx`, comme `DocxImportService` sur iOS.
 *
 * Un Word est un ZIP dont `word/document.xml` porte le corps. On le lit ici, dans
 * l'onglet : le serveur ne reçoit que le texte, jamais le fichier.
 */

import { looksLikeZip, zipEntryAt } from "./zip";

export { looksLikeZip };

export class DocxError extends Error {
  constructor(readonly code: "notDocx" | "missingDocument" | "empty") {
    super(code);
  }
}

export async function extractDocxText(bytes: Uint8Array): Promise<string> {
  if (!looksLikeZip(bytes)) throw new DocxError("notDocx");

  const xml = await zipEntryAt(bytes, "word/document.xml");
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

function normalize(text: string): string {
  return text.replace(/\u00a0/g, " ").replace(/[ \t]+\n/g, "\n").replace(/\n{3,}/g, "\n\n").trim();
}

function decodeEntities(value: string): string {
  return value
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'");
}
