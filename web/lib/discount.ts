import { discount } from "@micabo/core";

/**
 * Ce que l'appareil retient de l'offre cadeau.
 *
 * Deux clés, et pas une colonne en base. Le tarif réduit est une mécanique de
 * présentation : ce qui doit survivre à un changement d'appareil, c'est
 * l'abonnement, et il vit dans `entitlements`, écrit par le seul webhook
 * RevenueCat. Poser ici une colonne que personne d'autre n'écrit donnerait une
 * colonne qui finit par mentir.
 *
 * Conséquence assumée : l'offre repart sur un second appareil. C'est le même
 * compromis que `micabo.paywall.v2.dismissed`, et il vaut mieux qu'un utilisateur
 * revoie une offre qu'un utilisateur qui ne la voie jamais.
 */

export const DISCOUNT_STARTED_KEY = "micabo.discount.startedAt";
export const DISCOUNT_SEEN_KEY = "micabo.discount.seen";

/** L'instant où le cadeau s'est ouvert, ou `null` si personne ne l'a ouvert ici. */
export function readDiscountStart(): number | null {
  try {
    const stored = window.localStorage.getItem(DISCOUNT_STARTED_KEY);
    if (!stored) return null;
    const value = Number(stored);
    return Number.isFinite(value) && value > 0 ? value : null;
  } catch {
    return null;
  }
}

/**
 * Ouvre la fenêtre de l'offre, ou rend celle qui court déjà.
 *
 * Deux règles, et elles tirent en sens contraire. Une fenêtre **en cours** ne se
 * remet pas à zéro : sans ce garde, chaque affichage repousserait la fin des
 * vingt-quatre heures et le décompte ne descendrait plus. Une fenêtre **finie**,
 * elle, ouvre la suivante : l'offre revient, elle ne meurt pas. Le « déjà vue »
 * repart alors, puisqu'on parle d'une nouvelle fenêtre.
 */
export function startDiscount(now = Date.now()): number {
  const existing = readDiscountStart();
  if (existing !== null && discount.isLive(existing, now)) return existing;
  try {
    window.localStorage.setItem(DISCOUNT_STARTED_KEY, String(now));
    window.localStorage.removeItem(DISCOUNT_SEEN_KEY);
  } catch {
    // Un stockage refusé ne doit pas empêcher de voir l'offre.
  }
  return now;
}

/** La grande pop-up s'est déjà présentée sur cet appareil. */
export function isDiscountSeen(): boolean {
  try {
    return window.localStorage.getItem(DISCOUNT_SEEN_KEY) === "1";
  } catch {
    return false;
  }
}

/**
 * La carte a été montrée. **Et la fenêtre démarre ici aussi.**
 *
 * Sans ce démarrage, fermer la carte avant qu'elle n'ait posé son instant laissait
 * un « déjà vue » sans décompte : la pop-up ne se représentait plus (déjà vue) et la
 * pastille ne s'affichait pas (pas d'instant). Le tarif réduit devenait alors
 * introuvable dans tout le produit, sans que rien ne le signale.
 */
export function markDiscountSeen(now = Date.now()): number {
  const startedAt = startDiscount(now);
  try {
    window.localStorage.setItem(DISCOUNT_SEEN_KEY, "1");
  } catch {
    // Voir plus haut.
  }
  return startedAt;
}

export function forgetDiscount(): void {
  try {
    window.localStorage.removeItem(DISCOUNT_STARTED_KEY);
    window.localStorage.removeItem(DISCOUNT_SEEN_KEY);
  } catch {
    // Voir plus haut.
  }
}

/**
 * Faut-il ouvrir la grande pop-up ?
 *
 * Une fonction pure, pour que la règle se teste sans navigateur ni horloge.
 * `startedAt` à `null` veut dire « le cadeau n'a pas encore été ouvert ici » :
 * la pop-up se présente, et c'est elle qui pose l'instant.
 */
export function shouldOpenDiscount(input: {
  isPaid: boolean;
  courseCount: number;
  seen: boolean;
  startedAt: number | null;
  now: number;
  debug?: boolean;
}): boolean {
  if (input.debug) return true;
  if (input.isPaid) return false;
  // Le cadeau vient après le premier cours. Sans cours importé, il n'y a rien à
  // récompenser et l'offre passe pour une réclame.
  if (input.courseCount < 1) return false;
  // Un « déjà vue » sans instant d'ouverture est un état bâtard, laissé par une
  // version qui marquait la carte vue sans démarrer son décompte. On la représente :
  // rien n'a jamais été chronométré, donc rien n'a été offert.
  if (input.startedAt === null) return true;
  // Fenêtre en cours : une seule fois, la pastille prend ensuite le relais.
  if (discount.isLive(input.startedAt, input.now)) return !input.seen;
  // Fenêtre finie : l'offre revient, après son repos.
  return discount.hasRested(input.startedAt, input.now);
}

/**
 * **Une seule carte à la fois.**
 *
 * Le paywall ordinaire s'ouvre tout seul sur l'accueil, au bout de 980 ms. Si
 * le cadeau vient de se présenter, les deux se superposeraient et celle qu'on
 * lirait serait la dernière arrivée — c'est-à-dire pas celle qui porte le prix
 * réduit. Le cadeau lève donc ce drapeau, et le paywall différé y renonce.
 *
 * Un drapeau de module, pas un état React : il est lu dans le `setTimeout` d'un
 * autre composant, où aucune prop n'arrive.
 */
let offerClaimed = false;

export function claimOffer(): void {
  offerClaimed = true;
}

export function releaseOffer(): void {
  offerClaimed = false;
}

export function isOfferClaimed(): boolean {
  return offerClaimed;
}

/** Faut-il garder la pastille et son décompte ? */
export function shouldShowDiscountBadge(input: {
  isPaid: boolean;
  courseCount: number;
  seen: boolean;
  startedAt: number | null;
  now: number;
}): boolean {
  if (input.isPaid) return false;
  if (input.courseCount < 1) return false;
  if (!input.seen) return false;
  if (input.startedAt === null) return false;
  return discount.isLive(input.startedAt, input.now);
}
