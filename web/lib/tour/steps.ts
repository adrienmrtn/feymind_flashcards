/**
 * La visite guidée du site : **les quatre pages de la refonte**, et le chemin d'une leçon.
 *
 * Des données, pas de composant : le texte se relit ici sans ouvrir un écran, et la sélection
 * se teste sans navigateur. Chaque visite pose un voile percé sur une zone et avance au bouton :
 * c'est bon pour une page qu'on découvre, et il n'y a plus de session de révision à suivre
 * sans la mettre en pause.
 *
 * **Les zones vides sont expliquées au futur.** Un compte neuf n'a ni leçon ni examen :
 * attendre qu'il ait du contenu, c'est ne jamais se présenter à celui qui en a le plus besoin.
 * On dit donc ce qui viendra là.
 *
 * On ne parle pas de ce que le gratuit ferme. La visite montre le produit ; l'offre a son
 * écran, et elle est déjà passée quand celle-ci commence.
 */

export type TourMode = "guided" | "hint";

export interface TourStep {
  /** La valeur de `data-tour` posée sur la zone montrée. */
  anchor: string;
  title: string;
  body: string;
  /**
   * La barre latérale n'existe pas sous `lg` : ses bulles se sautent sur téléphone plutôt
   * que de montrer le vide.
   */
  desktopOnly?: boolean;
}

export interface Tour {
  /** Ce qui s'écrit dans `profiles.tour_seen`. */
  id: string;
  mode: TourMode;
  steps: readonly TourStep[];
}

const HOME: Tour = {
  id: "accueil",
  mode: "guided",
  steps: [
    { anchor: "nav", desktopOnly: true, title: "app.tour.home.nav.title", body: "app.tour.home.nav.body" },
    { anchor: "home-barre", title: "app.tour.home.bar.title", body: "app.tour.home.bar.body" },
    { anchor: "home-supports", title: "app.tour.home.supports.title", body: "app.tour.home.supports.body" },
    { anchor: "home-chiffres", title: "app.tour.home.numbers.title", body: "app.tour.home.numbers.body" },
  ],
};

const LESSONS: Tour = {
  id: "lecons",
  mode: "guided",
  steps: [{ anchor: "lecons-liste", title: "app.tour.lessons.list.title", body: "app.tour.lessons.list.body" }],
};

const LESSON: Tour = {
  id: "lecon",
  mode: "guided",
  steps: [
    { anchor: "lecon-chemin", title: "app.tour.lesson.path.title", body: "app.tour.lesson.path.body" },
    { anchor: "lecon-barre", title: "app.tour.lesson.bar.title", body: "app.tour.lesson.bar.body" },
  ],
};

const EXAMS: Tour = {
  id: "examen",
  mode: "guided",
  steps: [
    { anchor: "examen-prochain", title: "app.tour.exams.next.title", body: "app.tour.exams.next.body" },
    { anchor: "examen-blanc", title: "app.tour.exams.mock.title", body: "app.tour.exams.mock.body" },
  ],
};

const PROFILE: Tour = {
  id: "profil",
  mode: "guided",
  steps: [
    { anchor: "profil-carte", title: "app.tour.profile.card.title", body: "app.tour.profile.card.body" },
    { anchor: "profil-reglages", title: "app.tour.profile.settings.title", body: "app.tour.profile.settings.body" },
  ],
};

export const TOURS: readonly Tour[] = [HOME, LESSONS, LESSON, EXAMS, PROFILE];

export const TOUR_IDS: readonly string[] = TOURS.map((tour) => tour.id);

export function isTourId(value: unknown): value is string {
  return typeof value === "string" && TOUR_IDS.includes(value);
}

/** La visite de cette adresse, ou `null` s'il n'y en a pas. */
export function tourFor(input: { pathname: string }): Tour | null {
  const path = input.pathname.replace(/\/+$/, "") || "/app";

  if (path === "/app") return HOME;
  if (path === "/app/lecons") return LESSONS;
  if (/^\/app\/lecons\/[^/]+$/.test(path)) return LESSON;
  if (path === "/app/examen") return EXAMS;
  if (path === "/app/profil") return PROFILE;

  return null;
}

/** Les bulles qui ont un sens sur cette largeur d'écran. */
export function stepsForWidth(tour: Tour, width: number): readonly TourStep[] {
  const wide = width >= 1024;
  return tour.steps.filter((step) => wide || !step.desktopOnly);
}
