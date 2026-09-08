/**
 * Écrire une fiche depuis le navigateur, **sans Server Action**.
 *
 * Next relance un vol RSC à chaque action, et intercepte aussi un `fetch`
 * vers une URL sous `/app`. C'est ce vol qui affichait « This page couldn't
 * load » pendant que le cours s'écrivait déjà en base. Un POST vers `/api`
 * n'a pas ce vol.
 */

export const IMPORT_WRITE_PATH = "/api/import-course";

export interface WriteSheetResult {
  status: "ok" | "error" | "paywall";
  courseId?: string;
  message?: string;
}

function postJson(path: string, body: unknown): Promise<WriteSheetResult> {
  return new Promise((resolve) => {
    const xhr = new XMLHttpRequest();
    xhr.open("POST", path);
    xhr.setRequestHeader("Accept", "application/json");
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.timeout = 120_000;
    xhr.onload = () => {
      try {
        const payload = JSON.parse(xhr.responseText) as WriteSheetResult;
        if (payload.status === "ok" || payload.status === "error" || payload.status === "paywall") {
          resolve(payload);
          return;
        }
      } catch {
        // Corps illisible.
      }
      resolve({ status: "error", message: xhr.statusText || "error" });
    };
    xhr.onerror = () => resolve({ status: "error", message: "error" });
    xhr.ontimeout = () => resolve({ status: "error", message: "timeout" });
    xhr.send(JSON.stringify(body));
  });
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
  return postJson(IMPORT_WRITE_PATH, input);
}
