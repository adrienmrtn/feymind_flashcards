import { discount } from "@micabo/core";

/**
 * Ce que l'appareil retient de l'offre cadeau.
 *
 * Trois clés — l'instant, le « déjà vu », la demande en attente —, les mêmes noms que
 * `DiscountOffer.Key` côté Swift, et pas une colonne en base. Le tarif réduit est une mécanique de
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
    window.localStorage.removeItem(DISCOUNT_PENDING_KEY);
  } catch {
    // Voir plus haut.
  }
}

/**
 * Faut-il poser le cadeau ?
 *
 * Une fonction pure, pour que la règle se teste sans navigateur ni horloge : celle de
 * `DiscountOffer.shouldPresentGift`, portée dans `@micabo/core/discount`. `startedAt` à
 * `null` veut dire « le cadeau n'a pas encore été ouvert ici » : il se présente, et c'est son
 * ouverture qui pose l'instant.
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
  return discount.shouldPresentGift(input);
}

// MARK: - Le déclencheur

/**
 * Un paywall s'est refermé sans achat et le cadeau attend d'être posé — la clé de
 * `DiscountOffer.Key.pending`. Gardée sur l'appareil parce que le paywall du parcours d'accueil
 * peut se refermer pendant une navigation : l'hôte du cadeau la reprend en arrivant.
 */
export const DISCOUNT_PENDING_KEY = "micabo.discount.pending";

/** L'événement que l'hôte du cadeau écoute : `gift` (la boîte à déballer) ou `paywall`. */
export const DISCOUNT_EVENT = "micabo:discount";

export type DiscountStage = "gift" | "paywall";

export interface DiscountRequest {
  stage: DiscountStage;
}

/**
 * **Le paywall vient de se refermer sans achat** : le cadeau se pose, s'il est dû (pas abonné,
 * pas déjà vu pendant cette fenêtre, ou le repos passé). C'est `DiscountOffer.paywallClosed`.
 * Rend vrai quand le cadeau a été demandé.
 */
export function paywallClosed(isPaid: boolean, now = Date.now()): boolean {
  if (
    !discount.shouldPresentGift({
      isPaid,
      courseCount: discount.giftAfterCourses,
      seen: isDiscountSeen(),
      startedAt: readDiscountStart(),
      now,
    })
  ) {
    return false;
  }
  try {
    window.localStorage.setItem(DISCOUNT_PENDING_KEY, "1");
  } catch {
    // Sans stockage, l'événement suffit : l'hôte est déjà monté.
  }
  requestDiscount("gift");
  return true;
}

/** La demande en attente, retirée en la lisant : le cadeau ne tombe qu'une fois. */
export function takePendingGift(): boolean {
  try {
    if (window.localStorage.getItem(DISCOUNT_PENDING_KEY) !== "1") return false;
    window.localStorage.removeItem(DISCOUNT_PENDING_KEY);
    return true;
  } catch {
    return false;
  }
}

/** Ouvre le cadeau (`gift`) ou directement le tarif (`paywall`, depuis la pastille ou le profil). */
export function requestDiscount(stage: DiscountStage): void {
  if (typeof window === "undefined") return;
  window.dispatchEvent(new CustomEvent<DiscountRequest>(DISCOUNT_EVENT, { detail: { stage } }));
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

/** Faut-il garder la pastille et son décompte ? `DiscountOffer.shouldShowBadge`. */
export function shouldShowDiscountBadge(input: {
  isPaid: boolean;
  courseCount: number;
  seen: boolean;
  startedAt: number | null;
  now: number;
}): boolean {
  return discount.shouldShowBadge(input);
}
