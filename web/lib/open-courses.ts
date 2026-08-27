/**
 * Les cours ouverts dans la barre, comme des onglets.
 *
 * Un seul identifiant remplaçait l'ancien : ouvrir un cours fermait l'autre.
 * La liste tient plusieurs fiches, dans `sessionStorage`, et disparaît avec
 * l'onglet du navigateur.
 */

export const OPEN_COURSES_KEY = "micabo.app.openCourses";
export const OPEN_COURSE_LEGACY_KEY = "micabo.app.openCourse";
export const OPEN_COURSES_EVENT = "micabo:courses-change";
export const MAX_OPEN_COURSES = 8;

export interface OpenCourseTab {
  id: string;
  title: string;
  emoji: string;
}

export function isOpenCourseTab(value: unknown): value is OpenCourseTab {
  if (!value || typeof value !== "object") return false;
  const row = value as Record<string, unknown>;
  return (
    typeof row.id === "string" &&
    row.id.length > 0 &&
    typeof row.title === "string" &&
    typeof row.emoji === "string"
  );
}

/** Relit la liste, et reprend l'ancien onglet unique s'il reste. */
export function parseOpenCourses(raw: string | null, legacy: string | null): OpenCourseTab[] {
  if (raw) {
    try {
      const parsed = JSON.parse(raw) as unknown;
      if (Array.isArray(parsed)) {
        return parsed.filter(isOpenCourseTab).slice(0, MAX_OPEN_COURSES);
      }
    } catch {
      // Une valeur illisible ne doit pas faire perdre la barre.
    }
  }

  if (legacy) {
    try {
      const parsed = JSON.parse(legacy) as unknown;
      if (isOpenCourseTab(parsed)) return [parsed];
    } catch {
      // Voir plus haut.
    }
  }

  return [];
}

export function pinCourse(list: OpenCourseTab[], course: OpenCourseTab): OpenCourseTab[] {
  return [course, ...list.filter((item) => item.id !== course.id)].slice(0, MAX_OPEN_COURSES);
}

export function unpinCourse(list: OpenCourseTab[], id: string): OpenCourseTab[] {
  return list.filter((item) => item.id !== id);
}

export function readOpenCourses(): OpenCourseTab[] {
  if (typeof window === "undefined") return [];
  try {
    return parseOpenCourses(
      window.sessionStorage.getItem(OPEN_COURSES_KEY),
      window.sessionStorage.getItem(OPEN_COURSE_LEGACY_KEY),
    );
  } catch {
    return [];
  }
}

export function writeOpenCourses(courses: OpenCourseTab[]): void {
  if (typeof window === "undefined") return;
  try {
    window.sessionStorage.setItem(OPEN_COURSES_KEY, JSON.stringify(courses));
    window.sessionStorage.removeItem(OPEN_COURSE_LEGACY_KEY);
  } catch {
    // Un stockage refusé fait perdre les onglets, pas la navigation.
  }
  window.dispatchEvent(new CustomEvent(OPEN_COURSES_EVENT, { detail: courses }));
}

export function pinOpenCourse(course: OpenCourseTab): OpenCourseTab[] {
  const next = pinCourse(readOpenCourses(), course);
  writeOpenCourses(next);
  return next;
}

export function unpinOpenCourse(id: string): OpenCourseTab[] {
  const next = unpinCourse(readOpenCourses(), id);
  writeOpenCourses(next);
  return next;
}

export function clearOpenCourses(): void {
  if (typeof window === "undefined") return;
  try {
    window.sessionStorage.removeItem(OPEN_COURSES_KEY);
    window.sessionStorage.removeItem(OPEN_COURSE_LEGACY_KEY);
  } catch {
    // Voir plus haut.
  }
}
