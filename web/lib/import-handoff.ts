/**
 * L'écriture d'une fiche ne vit pas sur l'écran d'import : elle doit
 * couvrir le changement de route jusqu'à la fiche ouverte.
 *
 * Le voile (`IMPORT_HANDOFF_KEY`) ne survit **pas** au chargement de la
 * fiche : le garder hydratait `/app/c/:id` avec un état que le serveur n'a
 * pas, et Next remplaçait la page par l'écran d'erreur. On le lève avant
 * d'ouvrir. L'identifiant du cours neuf va dans une autre clé, uniquement
 * pour y revenir si Next casse encore.
 *
 * Un `location` vers une route API ou une page `/app/c/:id` reste une
 * navigation App Router : Next tente un vol RSC, affiche « This page
 * couldn't load », puis le document gagne. On quitte d'abord le document
 * courant (`document.write` / `blob:`) : le routeur n'existe plus, et le
 * chargement de la fiche est un vrai GET.
 */

export const IMPORT_HANDOFF_KEY = "micabo.app.importHandoff";
export const IMPORT_HANDOFF_EVENT = "micabo:import-handoff";
export const LAST_WRITTEN_COURSE_KEY = "micabo.app.lastWrittenCourse";

export interface ImportHandoff {
  name: string;
  courseId?: string;
  /** Instant où l'écriture a commencé, pour que le % survive au changement de page. */
  startedAt?: number;
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
    const startedAt =
      typeof row.startedAt === "number" && Number.isFinite(row.startedAt) ? row.startedAt : undefined;
    return { name: row.name, courseId, startedAt };
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
  const current = readImportHandoff();
  const startedAt =
    typeof next.startedAt === "number" && Number.isFinite(next.startedAt)
      ? next.startedAt
      : current?.startedAt ?? Date.now();
  const payload: ImportHandoff = { ...next, startedAt };
  try {
    window.sessionStorage.setItem(IMPORT_HANDOFF_KEY, JSON.stringify(payload));
  } catch {
    // Un stockage refusé ne doit pas arrêter l'écriture.
  }
  window.dispatchEvent(new Event(IMPORT_HANDOFF_EVENT));
}

export function rememberWrittenCourse(courseId: string): void {
  if (typeof window === "undefined") return;
  try {
    window.sessionStorage.setItem(LAST_WRITTEN_COURSE_KEY, courseId);
  } catch {
    // Voir plus haut.
  }
}

export function readWrittenCourse(): string | null {
  if (typeof window === "undefined") return null;
  try {
    const id = window.sessionStorage.getItem(LAST_WRITTEN_COURSE_KEY);
    return id && id.length > 0 ? id : null;
  } catch {
    return null;
  }
}

/** Attend que le voile d'écriture soit réellement peint avant d'appeler le serveur. */
export function waitForPaint(): Promise<void> {
  if (typeof window === "undefined") return Promise.resolve();
  return new Promise((resolve) => {
    window.requestAnimationFrame(() => {
      window.requestAnimationFrame(() => {
        window.setTimeout(resolve, 80);
      });
    });
  });
}

const GENERATED_PAGE =
  /^\/app\/(c\/[0-9a-f-]{36}(\/cartes)?|paquets\/[0-9a-f-]{36})$/i;

export function isGeneratedPagePath(pathname: string): boolean {
  return GENERATED_PAGE.test(pathname);
}

function bounceMarkup(absoluteUrl: string): string {
  const dest = JSON.stringify(absoluteUrl);
  const meta = absoluteUrl.replace(/&/g, "&amp;");
  return `<!DOCTYPE html><html lang="fr"><head><meta charset="utf-8"><meta http-equiv="refresh" content="0;url=${meta}"><title>Micabo</title><style>html,body{margin:0;height:100%;background:#F8F4F0}</style></head><body><script>location.replace(${dest});<\/script></body></html>`;
}

/**
 * Détruit le document App Router, puis charge la fiche. Tant que Next
 * tourne, n'importe quel `location` vers une URL du site est un vol SPA.
 */
function leaveAppRouter(absoluteUrl: string): void {
  const html = bounceMarkup(absoluteUrl);
  try {
    const doc = window.document;
    doc.open();
    doc.write(html);
    doc.close();
    return;
  } catch {
    // Certains navigateurs refusent d'écrire après le chargement.
  }
  try {
    const blobUrl = URL.createObjectURL(new Blob([html], { type: "text/html" }));
    Window.prototype.open.call(window, blobUrl, "_self");
    return;
  } catch {
    // Dernier recours : un chargement document, encore passible d'un vol.
  }
  window.location.replace(absoluteUrl);
}

/**
 * Ouvre la fiche par un chargement document, hors du routeur Next.
 */
export function openGeneratedPage(href: string): void {
  if (typeof window === "undefined") return;
  const url = new URL(href, window.location.origin);
  if (!isGeneratedPagePath(url.pathname)) {
    window.location.replace(new URL("/app", window.location.origin).href);
    return;
  }
  leaveAppRouter(`${window.location.origin}${url.pathname}${url.search}`);
}

/** Si l'écriture a réussi et que Next a quand même cassé la page, on y retourne. */
export function recoverGeneratedCourseIfAny(): boolean {
  if (typeof window === "undefined") return false;
  const courseId = readWrittenCourse();
  if (!courseId) return false;
  const target = `/app/c/${courseId}`;
  // Déjà sur la fiche : un reload ici bouclait (voile + hydratation).
  if (window.location.pathname.startsWith(target)) return false;
  leaveAppRouter(`${window.location.origin}${target}`);
  return true;
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
