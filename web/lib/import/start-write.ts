import { buildWriterPage, WRITER_ROOT_ID, type WriterCopy, type WriterInput } from "./writer-page";

/**
 * Remplace le document Next par la page d'écriture autonome.
 *
 * On reste sur l'origine du site (document.write), pour que le cookie de
 * session parte avec le POST. Un `blob:` n'a pas ce cookie.
 */
export function beginStandaloneWrite(input: WriterInput, copy: WriterCopy): boolean {
  if (typeof window === "undefined") return false;
  const html = buildWriterPage(input, copy, window.location.origin);
  try {
    const doc = window.document;
    doc.open();
    doc.write(html);
    doc.close();
    return Boolean(doc.getElementById(WRITER_ROOT_ID));
  } catch {
    return false;
  }
}
