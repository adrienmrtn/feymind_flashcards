/**
 * L'écriture d'une fiche ne vit pas sur l'écran d'import : elle doit
 * couvrir le changement de route jusqu'à la fiche ouverte.
 *
 * `ImportPanel` se démonte dès que la fiche s'ouvre. Sans ce relais, le
 * « Micabo écrit la fiche… » disparaît, et l'écran du cours n'est pas encore
 * là — le trou que l'on voyait sur le web.
 *
 * L'ouverture se fait par un GET de formulaire **après un POST JSON**, pas
 * par le routeur Next ni par `location.href` : les deux sont interceptés
 * et relançaient un vol RSC (« This page couldn't load »), alors que le
 * cours était déjà en base.
 */

export const IMPORT_HANDOFF_KEY = "micabo.app.importHandoff";
export const IMPORT_HANDOFF_EVENT = "micabo:import-handoff";

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

/**
 * Ouvre la fiche par un chargement document, hors du routeur Next.
 *
 * On passe par `/api/open-course` : ce n'est pas une page de l'app, donc
 * Next ne peut pas en faire un vol RSC. Un GET direct vers `/app/c/:id`
 * (location.href, form, assign) restait une navigation SPA.
 *
 * Ne pas abort la page courante : ça coupait les vols en cours et
 * affichait l'écran d'erreur sur l'import, alors que le cours était écrit.
 */
export function openGeneratedPage(href: string): void {
  if (typeof window === "undefined") return;
  const url = new URL(href, window.location.origin);
  const bounce = new URL("/api/open-course", window.location.origin);
  bounce.searchParams.set("to", `${url.pathname}${url.search}`);
  const form = document.createElement("form");
  form.method = "GET";
  form.action = bounce.pathname;
  const input = document.createElement("input");
  input.type = "hidden";
  input.name = "to";
  input.value = `${url.pathname}${url.search}`;
  form.appendChild(input);
  form.setAttribute("data-micabo-open", "");
  form.style.display = "none";
  document.body.appendChild(form);
  HTMLFormElement.prototype.submit.call(form);
}

/** Si l'écriture a réussi et que Next a quand même cassé la page, on y retourne. */
export function recoverGeneratedCourseIfAny(): boolean {
  if (typeof window === "undefined") return false;
  const current = readImportHandoff();
  if (!current?.courseId) return false;
  const target = `/app/c/${current.courseId}`;
  if (window.location.pathname === target) {
    window.location.reload();
    return true;
  }
  // Ici le routeur est déjà mort : un replace document suffit.
  window.location.replace(`${window.location.origin}${target}`);
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
