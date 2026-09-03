/**
 * La visite guidée du web : les zones et ce qu'on en dit.
 *
 * Des données, pas de composant : le texte se relit ici sans ouvrir un écran,
 * et la sélection se teste sans navigateur.
 *
 * **Deux façons de montrer.** `guided` pose un voile percé sur la zone et
 * avance au bouton : c'est bon pour une page qu'on découvre. `hint` ne pose
 * rien du tout et suit ce que fait l'étudiant, parce qu'une session de
 * révision ne se met pas en pause pour lire une notice.
 *
 * **Les zones vides sont expliquées au futur.** Un compte neuf n'a ni cours,
 * ni cartes, ni examens : attendre qu'il ait du contenu, c'est ne jamais se
 * présenter à celui qui en a le plus besoin. On dit donc ce qui viendra là.
 *
 * On ne parle pas de ce que le gratuit ferme. La visite montre le produit ;
 * l'offre a son écran, et elle est déjà passée quand celle-ci commence.
 */

export type TourMode = "guided" | "hint";

export interface TourStep {
  /** La valeur de `data-tour` posée sur la zone montrée. */
  anchor: string;
  title: string;
  body: string;
  /**
   * La barre latérale n'existe pas sous `lg`, elle est dans un tiroir fermé.
   * Ces bulles se sautent donc sur téléphone plutôt que de montrer le vide.
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
    {
      anchor: "nav",
      desktopOnly: true,
      title: "app.tour.home.nav.title",
      body: "app.tour.home.nav.body",
    },
    {
      anchor: "nav-importer",
      desktopOnly: true,
      title: "app.tour.home.import.title",
      body: "app.tour.home.import.body",
    },
    {
      anchor: "taches",
      title: "app.tour.home.tasks.title",
      body: "app.tour.home.tasks.body",
    },
    {
      anchor: "semaine",
      title: "app.tour.home.week.title",
      body: "app.tour.home.week.body",
    },
    {
      anchor: "examens",
      title: "app.tour.home.exams.title",
      body: "app.tour.home.exams.body",
    },
    {
      anchor: "amis",
      title: "app.tour.home.friends.title",
      body: "app.tour.home.friends.body",
    },
  ],
};

const REVIEW: Tour = {
  id: "reviser",
  mode: "guided",
  steps: [
    {
      anchor: "reviser-panneau",
      title: "app.tour.review.panel.title",
      body: "app.tour.review.panel.body",
    },
  ],
};

/**
 * Les deux bulles de la première carte.
 *
 * Sans voile et sans bouton « Suivant » : elles suivent la carte. La première
 * vit tant que la réponse est cachée, la seconde apparaît avec les quatre
 * notes. C'est le geste de l'étudiant qui fait avancer la visite, pas un
 * clic de plus.
 */
const SESSION: Tour = {
  id: "session",
  mode: "hint",
  steps: [
    {
      anchor: "session-reponse",
      title: "app.tour.session.reveal.title",
      body: "app.tour.session.reveal.body",
    },
    {
      anchor: "session-notes",
      title: "app.tour.session.grades.title",
      body: "app.tour.session.grades.body",
    },
  ],
};

const COURSES: Tour = {
  id: "cours",
  mode: "guided",
  steps: [
    {
      anchor: "cours-etagere",
      title: "app.tour.courses.shelf.title",
      body: "app.tour.courses.shelf.body",
    },
    {
      anchor: "cours-ajouter",
      title: "app.tour.courses.add.title",
      body: "app.tour.courses.add.body",
    },
  ],
};

const SHEET: Tour = {
  id: "cours-fiche",
  mode: "guided",
  steps: [
    {
      anchor: "fiche-texte",
      title: "app.tour.sheet.text.title",
      body: "app.tour.sheet.text.body",
    },
    {
      anchor: "fiche-cartes",
      title: "app.tour.sheet.cards.title",
      body: "app.tour.sheet.cards.body",
    },
    {
      anchor: "fiche-visibilite",
      title: "app.tour.sheet.visibility.title",
      body: "app.tour.sheet.visibility.body",
    },
  ],
};

const CARDS: Tour = {
  id: "cours-cartes",
  mode: "guided",
  steps: [
    {
      anchor: "cartes-etats",
      title: "app.tour.cards.states.title",
      body: "app.tour.cards.states.body",
    },
    {
      anchor: "cartes-generer",
      title: "app.tour.cards.generate.title",
      body: "app.tour.cards.generate.body",
    },
    {
      anchor: "cartes-liste",
      title: "app.tour.cards.list.title",
      body: "app.tour.cards.list.body",
    },
  ],
};

const EXAMS: Tour = {
  id: "examens",
  mode: "guided",
  steps: [
    {
      anchor: "examens-calendrier",
      title: "app.tour.exams.calendar.title",
      body: "app.tour.exams.calendar.body",
    },
    {
      anchor: "examens-ajouter",
      title: "app.tour.exams.add.title",
      body: "app.tour.exams.add.body",
    },
  ],
};

/**
 * Une seule bulle, et c'est un choix.
 *
 * Les listes de cette page (demandes reçues, amis, camarades) ne s'affichent
 * que si elles ont du monde : chez un compte neuf, il n'y a rien à montrer et
 * une bulle pointerait un rectangle de zéro pixel. La recherche, elle, est
 * toujours là, et c'est de toute façon par elle qu'on commence.
 */
const FRIENDS: Tour = {
  id: "amis",
  mode: "guided",
  steps: [
    {
      anchor: "amis-recherche",
      title: "app.tour.friends.search.title",
      body: "app.tour.friends.search.body",
    },
  ],
};

const PROFILE: Tour = {
  id: "profil",
  mode: "guided",
  steps: [
    {
      anchor: "profil-chiffres",
      title: "app.tour.profile.streak.title",
      body: "app.tour.profile.streak.body",
    },
    {
      anchor: "profil-maitrise",
      title: "app.tour.profile.mastery.title",
      body: "app.tour.profile.mastery.body",
    },
    {
      anchor: "profil-passees",
      title: "app.tour.profile.top.title",
      body: "app.tour.profile.top.body",
    },
  ],
};

const SETTINGS: Tour = {
  id: "reglages",
  mode: "guided",
  steps: [
    {
      anchor: "reglages-toi",
      title: "app.tour.settings.pace.title",
      body: "app.tour.settings.pace.body",
    },
    {
      anchor: "reglages-langue",
      title: "app.tour.settings.language.title",
      body: "app.tour.settings.language.body",
    },
  ],
};

const IMPORT: Tour = {
  id: "importer",
  mode: "guided",
  steps: [
    {
      anchor: "importer-panneau",
      title: "app.tour.import.drop.title",
      body: "app.tour.import.drop.body",
    },
  ],
};

export const TOURS: readonly Tour[] = [
  HOME,
  REVIEW,
  SESSION,
  COURSES,
  SHEET,
  CARDS,
  EXAMS,
  FRIENDS,
  PROFILE,
  SETTINGS,
  IMPORT,
];

export const TOUR_IDS: readonly string[] = TOURS.map((tour) => tour.id);

export function isTourId(value: unknown): value is string {
  return typeof value === "string" && TOUR_IDS.includes(value);
}

/**
 * La visite de cette adresse, ou `null` s'il n'y en a pas.
 *
 * La session partage son adresse avec l'écran qui la précède (`?go=1`), et ce
 * ne sont pas les mêmes zones : elle passe donc en premier.
 */
export function tourFor(input: { pathname: string; inSession: boolean }): Tour | null {
  const path = input.pathname.replace(/\/+$/, "") || "/app";

  if (path === "/app/reviser") return input.inSession ? SESSION : REVIEW;
  if (path === "/app") return HOME;
  if (path === "/app/cours") return COURSES;
  if (path === "/app/examens") return EXAMS;
  if (path === "/app/amis") return FRIENDS;
  if (path === "/app/reglages") return SETTINGS;
  if (path === "/app/importer") return IMPORT;
  if (path.startsWith("/app/profil")) return PROFILE;

  // L'atelier des cartes est sous la fiche : le plus spécifique se lit d'abord.
  if (/^\/app\/c\/[^/]+\/cartes$/.test(path)) return CARDS;
  if (/^\/app\/c\/[^/]+$/.test(path)) return SHEET;

  return null;
}

/** Les bulles qui ont un sens sur cette largeur d'écran. */
export function stepsForWidth(tour: Tour, width: number): readonly TourStep[] {
  const wide = width >= 1024;
  return tour.steps.filter((step) => wide || !step.desktopOnly);
}
