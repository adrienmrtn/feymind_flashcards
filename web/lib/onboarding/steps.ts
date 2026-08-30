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
  | "/commencer/importer"
  | "/commencer/fiches"
  | "/commencer/cartes"
  | "/commencer/reussir"
  | "/commencer/retention"
  | "/commencer/personnaliser"
  | "/commencer/pays"
  | "/commencer/niveau"
  | "/commencer/matieres"
  | "/commencer/ecole"
  | "/commencer/parcours"
  | "/commencer/compte"
  | "/app";

export interface Step {
  path: OnboardingPath;
  label: string;
  chrome: boolean;
}

export const STEPS: readonly Step[] = [
  { path: "/commencer/bienvenue", label: "Bienvenue", chrome: true },
  { path: "/commencer/importer", label: "Importe tes cours", chrome: true },
  { path: "/commencer/fiches", label: "Tes fiches", chrome: true },
  { path: "/commencer/cartes", label: "Comprendre ton cours", chrome: true },
  { path: "/commencer/reussir", label: "Tes examens", chrome: true },
  { path: "/commencer/retention", label: "La méthode", chrome: true },
  // La charnière : ce qui précède montre le produit, ce qui suit pose les questions.
  { path: "/commencer/personnaliser", label: "Personnalisation", chrome: true },
  { path: "/commencer/pays", label: "Ton pays", chrome: true },
  { path: "/commencer/niveau", label: "Ton niveau", chrome: true },
  { path: "/commencer/matieres", label: "Tes matières", chrome: true },
  { path: "/commencer/ecole", label: "Ton école", chrome: true },
  { path: "/commencer/parcours", label: "Ton parcours", chrome: true },
  // La création du compte est une **page** et non un écran de parcours : elle porte sa propre
  // mise en page, donc ni jauge ni flèche par-dessus.
  { path: "/commencer/compte", label: "Ton compte", chrome: false },
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
