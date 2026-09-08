/**
 * Écrire une fiche depuis le navigateur, **sans Server Action**.
 *
 * Next relance un vol RSC à chaque action, et intercepte aussi un `fetch`
 * vers une URL sous `/app`. C'est ce vol qui affichait « This page couldn't
 * load » pendant que le cours s'écrivait déjà en base. Un POST vers `/api`
 * n'a pas ce vol.
 */

export const IMPORT_WRITE_PATH = "/api/import-course";
export const REFRESH_LIBRARY_PATH = "/api/refresh-library";

export interface WriteSheetResult {
  status: "ok" | "error" | "paywall";
  courseId?: string;
  message?: string;
}

function browserFetch(input: RequestInfo | URL, init?: RequestInit): Promise<Response> {
  const impl = typeof window !== "undefined" ? window.fetch.bind(window) : fetch;
  return impl(input, init);
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
  const response = await browserFetch(IMPORT_WRITE_PATH, {
    method: "POST",
    headers: { Accept: "application/json", "Content-Type": "application/json" },
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

/** Invalide les listes après la peinture, sans vol RSC. */
export function refreshLibraryInBackground(): void {
  void browserFetch(REFRESH_LIBRARY_PATH, {
    method: "POST",
    headers: { Accept: "application/json" },
  });
}
