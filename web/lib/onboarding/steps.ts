/**
 * Les écrans du parcours, dans l'ordre.
 *
 * La landing (`/`) reste la vitrine. « Commencer » ouvre le premier écran, et les
 * suivants s'enchaînent un par un. Le compte arrive **à la fin** : demander une
 * adresse avant d'avoir rien montré, c'est demander un compte pour une app qu'on
 * n'a pas encore vue. Les réponses s'accumulent sur l'appareil, et se déversent
 * en base dès que la session existe.
 *
 * Le paywall n'est plus une étape : l'étudiant ouvre d'abord l'app, et l'offre
 * se pose ensuite par-dessus le tableau de bord.
 */

export type OnboardingPath =
  | "/commencer"
  | "/commencer/bienvenue"
  | "/commencer/examen"
  | "/commencer/importer"
  | "/commencer/plan"
  | "/commencer/ia"
  | "/commencer/feynman"
  | "/commencer/resultats"
  | "/commencer/personnaliser"
  | "/commencer/pays"
  | "/commencer/niveau"
  | "/commencer/matieres"
  | "/commencer/repos"
  | "/commencer/moyenne"
  | "/commencer/objectif"
  | "/commencer/ensemble"
  | "/commencer/parcours"
  | "/commencer/compte"
  | "/app";

export interface Step {
  path: OnboardingPath;
  label: string;
  /**
   * La clé du libellé affiché, pour la jauge.
   *
   * Elle vit **ici**, avec l'étape, et non dans une liste parallèle tenue par l'habillage :
   * cette liste-là avait pris un écran de retard le jour où « ton école » a disparu, et la
   * jauge annonçait « Ton école » sur l'écran du parcours. Une étape porte son nom.
   */
  labelKey: string;
  chrome: boolean;
}

export const STEPS: readonly Step[] = [
  // L'accueil n'a pas de jauge : une barre à zéro sur le premier écran annonce une file
  // d'attente avant d'avoir rien montré.
  { path: "/commencer/bienvenue", label: "Bienvenue", labelKey: "onboarding.stepBienvenue", chrome: false },
  { path: "/commencer/examen", label: "Ton examen", labelKey: "onboarding.stepExamen", chrome: true },
  { path: "/commencer/importer", label: "Tes documents", labelKey: "onboarding.stepImporter", chrome: true },
  { path: "/commencer/plan", label: "Ton plan", labelKey: "onboarding.stepPlan", chrome: true },
  { path: "/commencer/ia", label: "L'IA", labelKey: "onboarding.stepIa", chrome: true },
  { path: "/commencer/feynman", label: "La méthode Feynman", labelKey: "onboarding.stepFeynman", chrome: true },
  { path: "/commencer/resultats", label: "Tes résultats", labelKey: "onboarding.stepResultats", chrome: true },
  // La charnière : ce qui précède montre le produit, ce qui suit pose les questions.
  { path: "/commencer/personnaliser", label: "Personnalisation", labelKey: "onboarding.stepPersonnaliser", chrome: true },
  { path: "/commencer/pays", label: "Ton pays", labelKey: "onboarding.stepPays", chrome: true },
  { path: "/commencer/niveau", label: "Ton niveau", labelKey: "onboarding.stepNiveau", chrome: true },
  { path: "/commencer/matieres", label: "Tes matières", labelKey: "onboarding.stepMatieres", chrome: true },
  // Le rythme, puis le point de départ, puis là où on va. Les trois se suivent parce que la
  // réponse à l'une éclaire la suivante : on ne demande pas une moyenne visée avant de savoir
  // d'où elle part.
  { path: "/commencer/repos", label: "Tes jours de repos", labelKey: "onboarding.stepRepos", chrome: true },
  { path: "/commencer/moyenne", label: "Ta moyenne", labelKey: "onboarding.stepMoyenne", chrome: true },
  { path: "/commencer/objectif", label: "Ton objectif", labelKey: "onboarding.stepObjectif", chrome: true },
  { path: "/commencer/ensemble", label: "Ensemble", labelKey: "onboarding.stepEnsemble", chrome: true },
  { path: "/commencer/parcours", label: "Ton parcours", labelKey: "onboarding.stepParcours", chrome: true },
  // La création du compte est une **page** et non un écran de parcours : elle porte sa propre
  // mise en page, donc ni jauge ni flèche par-dessus.
  { path: "/commencer/compte", label: "Ton compte", labelKey: "onboarding.stepCompte", chrome: false },
];

export function stepIndex(path: string): number {
  return STEPS.findIndex((step) => step.path === path);
}

export function nextPath(path: string): OnboardingPath {
  const index = stepIndex(path);
  return STEPS[index + 1]?.path ?? "/app";
}

export function previousPath(path: string): OnboardingPath | "/" | null {
  const index = stepIndex(path);
  if (index === 0) return "/";
  if (index < 0) return null;
  return STEPS[index - 1]?.path ?? null;
}

/** Avancement de 0 à 1, sur les écrans à jauge. */
export function progressFor(path: string): number {
  const withChrome = STEPS.filter((step) => step.chrome);
  const position = withChrome.findIndex((step) => step.path === path);
  if (position < 0) return 0;
  return (position + 1) / withChrome.length;
}
