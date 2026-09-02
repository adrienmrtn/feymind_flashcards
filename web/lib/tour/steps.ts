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
      title: "Le menu",
      body: "Réviser, tes cours, tes examens. Tu reviens ici quand tu veux.",
    },
    {
      anchor: "nav-importer",
      desktopOnly: true,
      title: "Importer un cours",
      body: "Un PDF, des photos, du Word ou du texte collé. Micabo en fait une fiche à relire.",
    },
    {
      anchor: "taches",
      title: "Tâches du jour",
      body: "Ce que tu as à réviser aujourd'hui, cours par cours. La liste se remplit dès que tu as des cartes.",
    },
    {
      anchor: "semaine",
      title: "Ta semaine",
      body: "Un jour, une colonne. Tu vois ce que tu as révisé et ce qui arrive.",
    },
    {
      anchor: "examens",
      title: "Tes examens",
      body: "Pose une date, et Micabo fait passer les cartes du cours avant le jour J.",
    },
    {
      anchor: "amis",
      title: "Tes amis",
      body: "Ajoute tes camarades pour voir qui révise cette semaine.",
    },
  ],
};

const REVIEW: Tour = {
  id: "reviser",
  mode: "guided",
  steps: [
    {
      anchor: "reviser-panneau",
      title: "Ta session",
      body: "Micabo choisit les cartes à revoir aujourd'hui et leur ordre. Tu n'as qu'à commencer.",
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
      title: "Réponds de tête",
      body: "Cherche la réponse, puis retourne la carte. La barre espace marche aussi.",
    },
    {
      anchor: "session-notes",
      title: "Dis si c'était dur",
      body: "Ta note décide quand la carte revient. Facile la repousse loin, Difficile la ramène vite.",
    },
  ],
};

const COURSES: Tour = {
  id: "cours",
  mode: "guided",
  steps: [
    {
      anchor: "cours-etagere",
      title: "Ton étagère",
      body: "Chaque cours importé se pose ici, avec sa fiche et son paquet de cartes.",
    },
    {
      anchor: "cours-ajouter",
      title: "Ajouter un cours",
      body: "PDF, Word, texte collé ou vidéo YouTube. Micabo lit, puis écrit la fiche.",
    },
  ],
};

const SHEET: Tour = {
  id: "cours-fiche",
  mode: "guided",
  steps: [
    {
      anchor: "fiche-texte",
      title: "La fiche",
      body: "Ton cours réécrit pour se relire vite. Elle s'imprime aussi, si tu révises sur papier.",
    },
    {
      anchor: "fiche-cartes",
      title: "Les cartes",
      body: "Micabo écrit les questions depuis cette fiche. C'est ce que tu réviseras.",
    },
    {
      anchor: "fiche-visibilite",
      title: "Qui peut la retrouver",
      body: "Ta fiche est à toi. Tu peux l'ouvrir à tes amis si tu veux la partager.",
    },
  ],
};

const CARDS: Tour = {
  id: "cours-cartes",
  mode: "guided",
  steps: [
    {
      anchor: "cartes-etats",
      title: "Où en est le paquet",
      body: "À revoir, jamais vues, en cours. Les trois états de tes cartes.",
    },
    {
      anchor: "cartes-generer",
      title: "Écrire des cartes",
      body: "Micabo en propose depuis la fiche. Tu gardes celles qui te vont.",
    },
    {
      anchor: "cartes-liste",
      title: "Tes cartes",
      body: "Tu peux corriger une question, sa réponse, ou en ajouter une à la main.",
    },
  ],
};

const EXAMS: Tour = {
  id: "examens",
  mode: "guided",
  steps: [
    {
      anchor: "examens-calendrier",
      title: "Ton calendrier",
      body: "Les dates posées s'écrivent sur le jour. Clique un jour pour en ajouter une.",
    },
    {
      anchor: "examens-ajouter",
      title: "Ajouter un examen",
      body: "Une date, les cours concernés, l'intensité. Micabo remonte les cartes avant l'examen.",
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
      title: "Trouver tes amis",
      body: "Cherche un @, ou prends dans la liste de ton établissement.",
    },
  ],
};

const PROFILE: Tour = {
  id: "profil",
  mode: "guided",
  steps: [
    {
      anchor: "profil-chiffres",
      title: "Ta série",
      body: "Un jour révisé fait monter la série. Le nombre de cartes est juste à côté.",
    },
    {
      anchor: "profil-maitrise",
      title: "Ton niveau",
      body: "Tes cartes se rangent par maîtrise, des nouvelles à celles que tu sais par cœur.",
    },
    {
      anchor: "profil-passees",
      title: "Cartes les plus passées",
      body: "Celles qui reviennent le plus souvent. Souvent celles à reformuler.",
    },
  ],
};

const SETTINGS: Tour = {
  id: "reglages",
  mode: "guided",
  steps: [
    {
      anchor: "reglages-toi",
      title: "Ton rythme",
      body: "Le temps que tu veux y passer chaque jour, et la longueur de tes fiches.",
    },
    {
      anchor: "reglages-langue",
      title: "La langue des fiches",
      body: "Micabo écrit tes fiches dans cette langue, quel que soit ton pays.",
    },
  ],
};

const IMPORT: Tour = {
  id: "importer",
  mode: "guided",
  steps: [
    {
      anchor: "importer-panneau",
      title: "Dépose ton cours",
      body: "Lâche un fichier dans la page, colle du texte, ou donne un lien YouTube. Micabo lit, puis écrit la fiche.",
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
