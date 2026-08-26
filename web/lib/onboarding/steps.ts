/**
 * Les neuf écrans du parcours, dans l'ordre.
 *
 * **Le compte est au deuxième**, avant les questions. C'est l'inverse de l'iPhone, et c'est juste
 * des deux côtés : le tunnel iOS a dix-sept écrans pour donner une raison de créer un compte, le
 * web n'en a pas un — quelqu'un qui a installé une app s'est déjà engagé, quelqu'un qui arrive
 * d'une recherche ne s'est engagé à rien. Ça tombe bien, la règle de l'abonnement veut qu'on ne
 * vende jamais avant la connexion, et le paywall est le dernier écran.
 *
 * Chaque écran est une **vraie URL**. Le parcours iOS est strictement linéaire, sans retour ; le
 * web a une flèche retour de toute façon, et ne pas la servir ne rend pas le parcours linéaire, ça
 * le rend cassé.
 */

/**
 * Les chemins du parcours, en union littérale.
 *
 * Ce n'est pas de la coquetterie de typage : `typedRoutes` vérifie que chaque lien mène à une page
 * qui existe, et il a attrapé du premier coup deux liens vers des pages légales que je n'avais pas
 * écrites. Une `string` ici lui retirerait cette vérification exactement là où le parcours en a le
 * plus besoin — neuf écrans qui se poussent l'un l'autre.
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
  /** Ce que la barre de progression annonce, pour les lecteurs d'écran. */
  label: string;
  /**
   * La barre de progression et le retour n'apparaissent qu'à partir de l'écran 2 : sur l'accueil
   * et sur la création de compte, il n'y a encore rien derrière soi.
   */
  chrome: boolean;
}

export const STEPS: readonly Step[] = [
  { path: "/commencer", label: "Bienvenue", chrome: false },
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

export function previousPath(path: string): OnboardingPath | null {
  const index = stepIndex(path);
  if (index <= 0) return null;
  return STEPS[index - 1]?.path ?? null;
}

/**
 * L'avancement, de 0 à 1.
 *
 * Il se compte sur les écrans à habillage, pas sur les neuf : afficher une barre déjà au tiers sur
 * le premier écran qui en porte une donnerait l'impression d'avoir sauté quelque chose.
 */
export function progressFor(path: string): number {
  const withChrome = STEPS.filter((step) => step.chrome);
  const position = withChrome.findIndex((step) => step.path === path);
  if (position < 0) return 0;
  return (position + 1) / withChrome.length;
}
