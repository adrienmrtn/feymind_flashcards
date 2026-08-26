/**
 * Les écrans du parcours, dans l'ordre.
 *
 * La landing (`/`) reste la vitrine. « Commencer » ouvre le premier écran, et les
 * suivants s'enchaînent un par un. Le compte est en premier : sur le web on n'a pas
 * dix-sept écrans pour donner une raison d'en créer un, et on ne vend jamais avant
 * la connexion.
 */

export type OnboardingPath =
  | "/commencer"
  | "/commencer/compte"
  | "/commencer/pays"
  | "/commencer/niveau"
  | "/commencer/matieres"
  | "/commencer/examen"
  | "/commencer/demo"
  | "/commencer/ecole"
  | "/commencer/offre"
  | "/app";

export interface Step {
  path: OnboardingPath;
  label: string;
  chrome: boolean;
}

export const STEPS: readonly Step[] = [
  // La création du compte est une **page** et non un écran de parcours : elle porte sa propre
  // mise en page, donc ni jauge ni flèche par-dessus.
  { path: "/commencer/compte", label: "Ton compte", chrome: false },
  { path: "/commencer/pays", label: "Ton pays", chrome: true },
  { path: "/commencer/niveau", label: "Ton niveau", chrome: true },
  { path: "/commencer/matieres", label: "Tes matières", chrome: true },
  { path: "/commencer/examen", label: "Ton examen", chrome: true },
  { path: "/commencer/demo", label: "Comment ça marche", chrome: true },
  { path: "/commencer/ecole", label: "Ton école", chrome: true },
  { path: "/commencer/offre", label: "Micabo Pro", chrome: true },
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
