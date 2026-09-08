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
 * L'ouverture passe par `/api/open-course` via le setter natif de
 * `Location`, pour que le routeur App n'en fasse pas un vol SPA.
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

function hardNavigate(href: string): void {
  const desc = Object.getOwnPropertyDescriptor(Location.prototype, "href");
  if (desc?.set) {
    desc.set.call(window.location, href);
    return;
  }
  window.location.replace(href);
}

/**
 * Ouvre la fiche par un chargement document, hors du routeur Next.
 */
export function openGeneratedPage(href: string): void {
  if (typeof window === "undefined") return;
  const url = new URL(href, window.location.origin);
  const bounce = new URL("/api/open-course", window.location.origin);
  bounce.searchParams.set("to", `${url.pathname}${url.search}`);
  hardNavigate(bounce.href);
}

/** Si l'écriture a réussi et que Next a quand même cassé la page, on y retourne. */
export function recoverGeneratedCourseIfAny(): boolean {
  if (typeof window === "undefined") return false;
  const courseId = readWrittenCourse();
  if (!courseId) return false;
  const target = `/app/c/${courseId}`;
  // Déjà sur la fiche : un reload ici bouclait (voile + hydratation).
  if (window.location.pathname.startsWith(target)) return false;
  const bounce = new URL("/api/open-course", window.location.origin);
  bounce.searchParams.set("to", target);
  hardNavigate(bounce.href);
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
