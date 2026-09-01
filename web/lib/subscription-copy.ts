import { pricing } from "@micabo/core";

/**
 * Le texte de la carte Abonnement, **décidé ici** pour que l'écran et les
 * tests disent la même chose.
 *
 * Le bouton ouvre le bon magasin (Stripe, Apple, Play) côté serveur. Ici on
 * ne fait que nommer ce qu'on voit : gratuit, Pro, essai, cadeau, et où ça
 * se gère.
 */

export type SubscriptionStore = "app_store" | "play_store" | "stripe" | "promotional" | null;

export interface SubscriptionView {
  paid: boolean;
  store: SubscriptionStore;
  periodType: "trial" | "intro" | "normal" | null;
  expiresAt: string | null;
  willRenew: boolean;
  productId: string | null;
}

export function planTitleFor(productId: string | null): string | null {
  if (!productId) return null;
  const listed = pricing.STORE_PRODUCTS.find((product) => product.id === productId);
  if (listed) return pricing.catalogPlanFor(listed.plan).title;
  if (productId === pricing.YEARLY.productId) return pricing.YEARLY.title;
  if (productId === pricing.WEEKLY.productId) return pricing.WEEKLY.title;
  if (productId === pricing.DISCOUNT_YEARLY.productId) return pricing.DISCOUNT_YEARLY.title;
  return null;
}

export function subscriptionHeadline(view: SubscriptionView): string {
  if (!view.paid) return "Gratuit";
  if (view.store === "promotional") return "Accès offert";
  if (view.periodType === "trial") return "Essai Micabo Pro";
  return "Micabo Pro";
}

export function subscriptionDetail(view: SubscriptionView): string {
  if (!view.paid) {
    return "Un cours offert. Pro ouvre le reste : cartes, fiches, entraînement.";
  }
  if (view.store === "promotional") {
    return "Cet accès a été offert. Il n'y a rien à résilier ici.";
  }

  const origin =
    view.store === "app_store"
      ? "Pris sur l'iPhone."
      : view.store === "play_store"
        ? "Pris sur le Play Store."
        : "Pris sur le web.";
  const when = renewalLine(view);
  return when ? `${origin} ${when}` : origin;
}

export function manageLabel(view: SubscriptionView): string | null {
  if (!view.paid) return "Voir l'offre";
  if (view.store === "promotional") return null;
  if (view.store === "app_store") return "Gérer dans l'App Store";
  if (view.store === "play_store") return "Gérer dans le Play Store";
  return "Gérer mon abonnement";
}

function renewalLine(view: SubscriptionView): string | null {
  if (!view.expiresAt) return null;
  const day = formatDay(view.expiresAt);
  if (!day) return null;
  if (view.periodType === "trial") return `Jusqu'au ${day}.`;
  if (view.willRenew) return `Prochain prélèvement le ${day}.`;
  return `S'arrête le ${day}.`;
}

function formatDay(iso: string): string | null {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return null;
  return new Intl.DateTimeFormat("fr-FR", { day: "numeric", month: "long" }).format(date);
}
