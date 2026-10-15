/**
 * **La base d'icônes 3D, côté serveur** : les icônes qu'un modèle peut donner à une leçon ou à
 * un thème, et ce que chacune évoque.
 *
 * C'est la même table que `MicaboIcon.lessonCatalog` dans l'app
 * (`Micabo/DesignSystem/MicaboIcon.swift`), dans le même ordre : l'identifiant est le nom du
 * fichier de l'icône. `icons.test.ts` vérifie que les deux listes ne divergent pas.
 */
export const LESSON_ICONS: ReadonlyArray<{ id: string; meaning: string }> = [
  { id: "livre-ouvert", meaning: "par défaut, lecture, littérature, langues" },
  { id: "globe", meaning: "géographie, monde, pays, environnement" },
  { id: "fiole", meaning: "chimie, expériences, biologie de laboratoire" },
  { id: "parchemin", meaning: "histoire, textes anciens, droit, traités" },
  { id: "calculatrice", meaning: "mathématiques, calcul, statistiques, économie chiffrée" },
  { id: "atome", meaning: "physique, particules, énergie" },
  { id: "ampoule", meaning: "idée clé, définition, principe, invention" },
  { id: "loupe", meaning: "analyse, méthode, étude de cas, enquête" },
  { id: "puzzle", meaning: "mécanisme, liens entre notions, système" },
  { id: "cerveau", meaning: "psychologie, mémoire, philosophie, raisonnement" },
  { id: "reveil", meaning: "chronologie, dates, durées, rythmes" },
  { id: "sablier", meaning: "évolution, époque, temps long" },
  { id: "plume", meaning: "écriture, rédaction, auteurs, poésie" },
  { id: "palette", meaning: "arts, couleurs, design, culture" },
  { id: "fusee", meaning: "progrès, espace, innovation, technologie" },
  { id: "drapeau", meaning: "nation, politique, guerre, conquête" },
  { id: "diplome", meaning: "méthodologie d'examen, programme, synthèse" },
  { id: "epingle", meaning: "lieux, cartes, repères" },
  { id: "coche", meaning: "règles, procédures, étapes à suivre" },
  { id: "cadenas", meaning: "sécurité, protection, notions difficiles" },
  { id: "etoile", meaning: "essentiel, à retenir" },
  { id: "trophee", meaning: "réussite, bilan, records" },
  { id: "couronne", meaning: "pouvoir, monarchie, souverains" },
  { id: "flamme", meaning: "énergie, combustion, révolutions, passions" },
  { id: "examen", meaning: "calendrier, événements datés" },
];

export const DEFAULT_ICON = "livre-ouvert";

const KNOWN = new Set(LESSON_ICONS.map((icon) => icon.id));

/** Un identifiant rendu par le modèle, ramené à la base ; inconnu, il devient le livre. */
export function normalizeIcon(value: unknown): string {
  if (typeof value !== "string") return DEFAULT_ICON;
  const id = value.trim().toLowerCase()
    .normalize("NFD").replace(/[̀-ͯ]/g, "")
    .replace(/\s+/g, "-");
  return KNOWN.has(id) ? id : DEFAULT_ICON;
}

/** La liste telle qu'elle part dans le prompt. */
export function iconBrief(): string {
  return LESSON_ICONS.map((icon) => `- ${icon.id} : ${icon.meaning}`).join("\n");
}
