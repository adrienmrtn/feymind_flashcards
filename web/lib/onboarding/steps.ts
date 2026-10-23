import { isDetailedCountry, trackById } from "./school-system";

/**
 * Les écrans du parcours, dans l'ordre.
 *
 * **Le parcours est un quiz court, puis le compte, puis l'offre** - l'ordre de l'iPhone
 * (`OnboardingStep.swift`), resserré pour le site. L'étudiant qui clique « Commencer » vient de
 * lire la vitrine : il a déjà vu le produit. Les six écrans de démonstration qui ouvraient le
 * parcours le lui remontraient avant la première question, et un chargement de sept secondes
 * fermait la marche. Ils sont partis ; ne restent que les questions qui **changent quelque
 * chose** - la leçon que Mika écrit, ou le plan - et un écran qui relit les réponses.
 *
 * Chaque réponse a sa destination, et c'est la règle d'entrée d'une question ici :
 *
 * | Écran      | Réponse                    | Où elle va                                              |
 * | ---------- | -------------------------- | ------------------------------------------------------- |
 * | pays       | le pays                    | `profiles.country_code` : langue des notes, barème       |
 * | niveau     | palier, ou filière         | `profiles.study_level`, cookie `micabo.learner` (s, t, k) |
 * | classe     | l'année                    | cookie (y) : `year` et la marche de `generate-lesson`     |
 * | matieres   | les matières               | `profiles.subjects`                                      |
 * | freins     | ce qui bloque              | cookie (w) : `worries` de `generate-lesson`               |
 * | moyenne    | moyenne actuelle et visée  | cookie (c, g) : exemples et exigence de la leçon          |
 * | rythme     | minutes par jour, repos    | `profiles.daily_minutes`, `profiles.weekly_minutes`       |
 * | examen     | la date                    | une ligne `exams` : le plan et le mode examen             |
 *
 * Les réponses s'accumulent sur l'appareil, et se déversent en base dès que la session existe.
 * **Le paywall suit immédiatement le compte** : c'est le moment où l'étudiant vient de dire ce
 * qu'il veut, et il n'a pas encore été distrait par autre chose.
 */

export type OnboardingPath =
  | "/commencer"
  | "/commencer/bienvenue"
  | "/commencer/pays"
  | "/commencer/niveau"
  | "/commencer/classe"
  | "/commencer/matieres"
  | "/commencer/freins"
  | "/commencer/moyenne"
  | "/commencer/rythme"
  | "/commencer/examen"
  | "/commencer/parcours"
  | "/commencer/compte"
  | "/commencer/offre"
  | "/app";

export interface Step {
  path: OnboardingPath;
  /**
   * La clé du libellé affiché, pour la jauge.
   *
   * Elle vit **ici**, avec l'étape, et non dans une liste parallèle tenue par l'habillage :
   * cette liste-là avait pris un écran de retard le jour où « ton école » a disparu, et la
   * jauge annonçait « Ton école » sur l'écran du parcours. Une étape porte son nom.
   */
  labelKey: string;
  /** La jauge et le retour. Ni l'accueil, ni le compte, ni l'offre : ce sont des pages. */
  chrome: boolean;
}

export const STEPS: readonly Step[] = [
  { path: "/commencer/bienvenue", labelKey: "onboarding.stepBienvenue", chrome: false },
  { path: "/commencer/pays", labelKey: "onboarding.stepPays", chrome: true },
  { path: "/commencer/niveau", labelKey: "onboarding.stepNiveau", chrome: true },
  { path: "/commencer/classe", labelKey: "onboarding.stepClasse", chrome: true },
  { path: "/commencer/matieres", labelKey: "onboarding.stepMatieres", chrome: true },
  { path: "/commencer/freins", labelKey: "onboarding.stepFreins", chrome: true },
  { path: "/commencer/moyenne", labelKey: "onboarding.stepMoyenne", chrome: true },
  { path: "/commencer/rythme", labelKey: "onboarding.stepRythme", chrome: true },
  { path: "/commencer/examen", labelKey: "onboarding.stepExamen", chrome: true },
  { path: "/commencer/parcours", labelKey: "onboarding.stepParcours", chrome: true },
  { path: "/commencer/compte", labelKey: "onboarding.stepCompte", chrome: false },
  { path: "/commencer/offre", labelKey: "onboarding.stepOffre", chrome: false },
];

/** Ce que le choix des écrans a besoin de savoir des réponses. */
export interface StepContext {
  country?: string;
  trackId?: string;
}

/**
 * **Les écrans sautés, selon ce qui a été répondu** - `OnboardingStep.isSkipped(for:)`.
 *
 * L'année ne se demande qu'aux pays décrits en détail, et une fois la filière connue : ailleurs,
 * lui proposer « Terminale » serait inventer une réponse fausse.
 */
export function isSkipped(path: string, context: StepContext = {}): boolean {
  if (path !== "/commencer/classe") return false;
  // Pays pas encore choisi : l'écran compte. La jauge peut alors raccourcir d'un cran au choix
  // du pays - une bonne nouvelle - plutôt que de s'allonger en cours de route.
  if (!context.country) return false;
  if (!isDetailedCountry(context.country)) return true;
  const track = trackById(context.trackId, context.country);
  // Filière pas encore choisie : l'écran reste dans le compte, la jauge ne recule pas ensuite.
  return track ? track.years.length === 0 : false;
}

export function stepIndex(path: string): number {
  return STEPS.findIndex((step) => step.path === path);
}

/** Les écrans que cet étudiant-là traverse, dans l'ordre. */
export function visibleSteps(context: StepContext = {}): Step[] {
  return STEPS.filter((step) => !isSkipped(step.path, context));
}

export function nextPath(path: string, context: StepContext = {}): OnboardingPath {
  const index = stepIndex(path);
  if (index < 0) return "/app";
  for (const step of STEPS.slice(index + 1)) {
    if (!isSkipped(step.path, context)) return step.path;
  }
  return "/app";
}

export function previousPath(path: string, context: StepContext = {}): OnboardingPath | "/" | null {
  const index = stepIndex(path);
  if (index === 0) return "/";
  if (index < 0) return null;
  for (const step of STEPS.slice(0, index).reverse()) {
    if (!isSkipped(step.path, context)) return step.path;
  }
  return "/";
}

/** Avancement de 0 à 1, sur les écrans à jauge que cet étudiant traverse. */
export function progressFor(path: string, context: StepContext = {}): number {
  const withChrome = visibleSteps(context).filter((step) => step.chrome);
  const position = withChrome.findIndex((step) => step.path === path);
  if (position < 0) return 0;
  return (position + 1) / withChrome.length;
}
