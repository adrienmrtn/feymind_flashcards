/**
 * Écrire une fiche depuis le navigateur, **sans Server Action**.
 *
 * Next relance un vol RSC à chaque action, même sans `revalidatePath`.
 * C'est ce vol qui affichait « This page couldn't load » pendant que le
 * cours s'écrivait déjà en base. Un `fetch` n'a pas ce vol.
 */

export const IMPORT_WRITE_PATH = "/app/importer/write";

export interface WriteSheetResult {
  status: "ok" | "error" | "paywall";
  courseId?: string;
  message?: string;
}

export async function writeSheetFromBrowser(input: {
  text: string;
  hintTitle?: string;
  sourceName?: string;
  source?: "text" | "pdf" | "docx" | "youtube";
  visibility?: string;
  blocks?: number;
  length?: string;
  language?: string;
  instructions?: string;
  images?: string[];
}): Promise<WriteSheetResult> {
  const response = await fetch(IMPORT_WRITE_PATH, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  });

  try {
    const payload = (await response.json()) as WriteSheetResult;
    if (payload.status === "ok" || payload.status === "error" || payload.status === "paywall") {
      return payload;
    }
  } catch {
    // Un corps vide ou illisible : on tombe sur l'erreur générique.
  }

  return { status: "error", message: response.statusText || "error" };
}
