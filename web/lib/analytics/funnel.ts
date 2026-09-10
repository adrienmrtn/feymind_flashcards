import { track } from "@vercel/analytics";

import { stepIndex, STEPS } from "../onboarding/steps";

/**
 * **L'entonnoir, de la première page d'accueil jusqu'au paiement.**
 *
 * Les pages vues de Vercel disent déjà combien de gens ont chargé `/commencer/repos`. Elles
 * ne disent pas dans quel **ordre** une même personne les a traversées, ni où le paywall se
 * trouve : il n'a pas d'adresse, c'est une carte posée sur `/app`, et Vercel ne voit qu'un
 * chargement de `/app` de plus. Sans événement, l'entonnoir s'arrête au compte.
 *
 * Quatre événements suffisent, et ils portent tous une **marche numérotée** : dans Vercel,
 * on filtre `onboarding_step` par `step` et on lit les nombres dans l'ordre. La marche où
 * ça s'effondre est l'écran qui perd les gens.
 *
 * | Événement          | Quand                                             | Propriétés                    |
 * | ------------------ | ------------------------------------------------- | ----------------------------- |
 * | `onboarding_step`  | à chaque écran du parcours `/commencer/*`         | `step`, `index`, `of`         |
 * | `paywall_view`     | la carte de l'offre s'ouvre (accueil, séance, cadeau) | `surface`, `stage`        |
 * | `checkout_start`   | clic sur « S'abonner », avant le départ vers Stripe | `plan`, `surface`           |
 * | `checkout_success` | retour de Stripe sur `/app?abonnement=ok`         | -                             |
 *
 * `track()` ne fait rien hors de Vercel et n'échoue jamais : un bloqueur de publicité qui
 * l'avale ne casse pas la page. Il demande le plan Pro, que l'équipe a.
 */

export const FUNNEL_EVENTS = {
  step: "onboarding_step",
  paywall: "paywall_view",
  checkout: "checkout_start",
  paid: "checkout_success",
} as const;

/** D'où l'offre s'est ouverte. Le même écran, trois portes, et elles ne convertissent pas pareil. */
export type PaywallSurface = "home" | "session" | "discount";

export interface StepEvent {
  /** Le dernier segment de l'adresse : `bienvenue`, `repos`, `compte`… */
  step: string;
  /** Sa place dans le parcours, à partir de 1. */
  index: number;
  /** Le nombre de marches, pour lire `index` sans ouvrir le code. */
  of: number;
}

/**
 * La marche que représente une adresse, ou `null` hors du parcours. Pure, pour le test : le
 * calcul est la seule chose qui puisse se tromper, `track()` n'est qu'un envoi.
 */
export function stepEvent(pathname: string): StepEvent | null {
  const index = stepIndex(pathname);
  const found = index >= 0 ? STEPS[index] : undefined;
  if (!found) return null;
  const step = found.path.split("/").pop() ?? "";
  return { step, index: index + 1, of: STEPS.length };
}

export function trackOnboardingStep(pathname: string): void {
  const event = stepEvent(pathname);
  if (!event) return;
  track(FUNNEL_EVENTS.step, { ...event });
}

export function trackPaywallView(
  surface: PaywallSurface,
  stage = "plans",
): void {
  track(FUNNEL_EVENTS.paywall, { surface, stage });
}

export function trackCheckoutStart(
  plan: string,
  surface: PaywallSurface,
): void {
  track(FUNNEL_EVENTS.checkout, { plan, surface });
}

export function trackCheckoutSuccess(): void {
  track(FUNNEL_EVENTS.paid);
}
