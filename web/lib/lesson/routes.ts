import type { Route } from "next";

/**
 * **Les adresses de la leçon**, nommées une fois.
 *
 * `LESSONS_PATH` est l'onglet Leçons. Il pointe encore sur l'ancienne liste des cours tant
 * que la nouvelle n'est pas écrite (lot 6 de `docs/refonte-web.md`) : une seule constante à
 * changer ce jour-là, et aucun lien mort entre-temps.
 */
export const LESSONS_PATH = "/app/cours" as Route;

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
