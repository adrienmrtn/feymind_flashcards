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
  | "/commencer/pays"
  | "/commencer/niveau"
  | "/commencer/matieres"
  | "/commencer/examen"
  | "/commencer/comment"
  | "/commencer/demo"
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
  { path: "/commencer/pays", label: "Ton pays", chrome: true },
  { path: "/commencer/niveau", label: "Ton niveau", chrome: true },
  { path: "/commencer/matieres", label: "Tes matières", chrome: true },
  { path: "/commencer/examen", label: "Ton examen", chrome: true },
  { path: "/commencer/comment", label: "Voici comment ça marche", chrome: true },
  { path: "/commencer/demo", label: "Comment ça marche", chrome: true },
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
