/**
 * L'écriture d'une fiche ne vit pas sur l'écran d'import : elle doit
 * couvrir le changement de route jusqu'à la fiche ouverte.
 *
 * `ImportPanel` se démonte dès que `router.push` part. Sans ce relais, le
 * « Micabo écrit la fiche… » disparaît, et l'écran du cours n'est pas encore
 * là — le trou que l'on voyait sur le web.
 */

export const IMPORT_HANDOFF_KEY = "micabo.app.importHandoff";
export const IMPORT_HANDOFF_EVENT = "micabo:import-handoff";

export interface ImportHandoff {
  name: string;
  courseId?: string;
}

export function parseImportHandoff(raw: string | null): ImportHandoff | null {
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as unknown;
    if (!parsed || typeof parsed !== "object") return null;
    const row = parsed as Record<string, unknown>;
    if (typeof row.name !== "string") return null;
    const courseId =
      typeof row.courseId === "string" && row.courseId.length > 0 ? row.courseId : undefined;
    return { name: row.name, courseId };
  } catch {
    return null;
  }
}

export function readImportHandoff(): ImportHandoff | null {
  if (typeof window === "undefined") return null;
  try {
    return parseImportHandoff(window.sessionStorage.getItem(IMPORT_HANDOFF_KEY));
  } catch {
    return null;
  }
}

export function holdImportHandoff(next: ImportHandoff): void {
  if (typeof window === "undefined") return;
  try {
    window.sessionStorage.setItem(IMPORT_HANDOFF_KEY, JSON.stringify(next));
  } catch {
    // Un stockage refusé ne doit pas arrêter l'écriture.
  }
  window.dispatchEvent(new Event(IMPORT_HANDOFF_EVENT));
}

export function releaseImportHandoff(courseId?: string): void {
  if (typeof window === "undefined") return;
  const current = readImportHandoff();
  if (courseId && current?.courseId && current.courseId !== courseId) return;
  try {
    window.sessionStorage.removeItem(IMPORT_HANDOFF_KEY);
  } catch {
    // Voir plus haut.
  }
  window.dispatchEvent(new Event(IMPORT_HANDOFF_EVENT));
}
