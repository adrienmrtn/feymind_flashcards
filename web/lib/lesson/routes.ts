import type { Route } from "next";

/**
 * **Les adresses de la leçon**, nommées une fois.
 *
 * `LESSONS_PATH` est l'onglet Leçons ; l'ancienne liste des cours (`/app/cours`) y redirige.
 */
/** Home : la question, la barre, « Reprendre ». */
export const HOME_PATH = "/app" as Route;
export const LESSONS_PATH = "/app/lecons" as Route;
/** L'onglet Examen. */
export const EXAMS_PATH = "/app/examen" as Route;
/** L'onglet Profil ; les anciens Réglages et Amis y mènent. */
export const PROFILE_PATH = "/app/profil" as Route;
export const FRIENDS_PATH = "/app/profil/amis" as Route;

export function lessonPath(id: string): Route {
  return `/app/lecons/${id}` as Route;
}

/** L'écran d'une étape du chemin : `/app/lecons/<id>/etape/<étape>`. */
export function stepPath(id: string, circleId: string): Route {
  return `/app/lecons/${id}/etape/${encodeURIComponent(circleId)}` as Route;
}

export function notesPath(id: string): Route {
  return `/app/lecons/${id}/notes` as Route;
}

export function quizPath(id: string): Route {
  return `/app/lecons/${id}/quiz` as Route;
}

export function flashcardsPath(id: string): Route {
  return `/app/lecons/${id}/flashcards` as Route;
}

/** Mika, la leçon jointe : `/app/lecons/<id>/mika`. */
export function mikaPath(id: string): Route {
  return `/app/lecons/${id}/mika` as Route;
}

/**
 * Vrai dans une leçon — son chemin ou l'une de ses pages. Sous `lg`, l'en-tête de l'onglet s'y
 * efface : chaque écran de la leçon porte sa propre barre, et deux barres l'une sur l'autre
 * disaient deux fois la même chose.
 */
export function insideLesson(pathname: string): boolean {
  return /^\/app\/lecons\/[^/]+/.test(pathname);
}
