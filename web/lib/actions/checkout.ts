"use server";

import { entitlement, pricing } from "@micabo/core";

import { SITE_URL } from "@/lib/config";
import { readEntitlement } from "@/lib/data/entitlement";
import {
  checkoutReturnUrl,
  checkoutSessionFields,
  extractStripeMessage,
  priceIdFor,
  priceIdProblem,
  stripeRefusalMessage,
} from "@/lib/stripe/checkout";
import { createClient } from "@/lib/supabase/server";

/**
 * L'encaissement web : Stripe Checkout, puis RevenueCat écrit le droit.
 *
 * Tant que `STRIPE_SECRET_KEY` manque, le bouton dit que l'abonnement n'est
 * pas ouvert. Un 400 de Stripe affiche désormais le motif réel — un `price_…`
 * inconnu, un tarif one-time, un e-mail vide — et plus seulement un statut nu.
 *
 * ## Ce qui est déjà décidé, et qui ne bougera pas
 *
 * **Stripe encaisse, RevenueCat détient le droit.** Le paiement ne met jamais à jour
 * `entitlements` directement : il crée un abonnement Stripe, RevenueCat le voit, et c'est **son
 * webhook** qui écrit. Une seule plume sur cette table, sinon deux sources finissent par ne pas
 * être d'accord sur qui paye - et c'est la panne dont personne ne se remet.
 *
 * Corollaire : `client_reference_id` porte l'`auth.users.id`, comme `app_user_id` chez RevenueCat.
 * C'est la même règle que partout, et c'est elle qui fait qu'un achat sur le web s'ouvre sur
 * l'iPhone.
 *
 * ## Ce qu'il manque, précisément
 *
 * `STRIPE_SECRET_KEY`. Les trois `price_…` sont dans `pricing.STORE_PRODUCTS` ;
 * une variable d'environnement les remplace (test / live) si elle est posée.
 */

export interface CheckoutResult {
  status: "redirect" | "unavailable" | "already" | "error";
  url?: string;
  message?: string;
}

function stripeKey(): string | null {
  return process.env.STRIPE_SECRET_KEY ?? null;
}

/** L'identifiant de prix Stripe. L'env gagne s'il n'est pas vide ; sinon le catalogue. */
function priceId(kind: pricing.PlanKind): string {
  return priceIdFor(
    kind,
    {
      yearly: process.env.STRIPE_PRICE_YEARLY,
      weekly: process.env.STRIPE_PRICE_WEEKLY,
    },
    pricing.stripePriceId,
  );
}

export async function startCheckout(kind: pricing.PlanKind): Promise<CheckoutResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  // **On ne vend jamais avant la connexion.** Ce n'est pas une commodité : `client_reference_id`
  // doit porter l'identifiant Supabase, et un achat rattaché à un identifiant anonyme est un
  // achat qu'on ne saura pas rendre à son propriétaire.
  if (!user) {
    return { status: "error", message: "Connecte-toi avant de t'abonner." };
  }

  const already = await readEntitlement();
  if (entitlement.isPaid(already)) return { status: "already" };

  const key = stripeKey();
  const price = priceId(kind);
  const plan = pricing.planFor(kind);

  if (!key) {
    return {
      status: "unavailable",
      message: "L'abonnement n'est pas encore ouvert.",
    };
  }

  const badPrice = priceIdProblem(price);
  if (badPrice) {
    return { status: "error", message: `${badPrice} Offre : ${plan.title}.` };
  }

  const response = await fetch("https://api.stripe.com/v1/checkout/sessions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams(
      checkoutSessionFields({
        price,
        userId: user.id,
        email: user.email,
        trialDays: pricing.hasTrial(plan) ? plan.trialDays : 0,
        successUrl: checkoutReturnUrl(SITE_URL, "/app?abonnement=ok"),
        cancelUrl: checkoutReturnUrl(SITE_URL, "/app"),
      }),
    ),
  });

  if (!response.ok) {
    const payload: unknown = await response.json().catch(() => null);
    console.error("stripe.checkout", response.status, extractStripeMessage(payload));
    return {
      status: "error",
      message: stripeRefusalMessage(response.status, payload, plan.title),
    };
  }

  const session = (await response.json()) as { url?: string };
  if (!session.url) return { status: "error", message: "Stripe n'a pas rendu de page de paiement." };

  return { status: "redirect", url: session.url };
}

/**
 * « Gérer mon abonnement », vers **le bon magasin.**
 *
 * C'est le piège classique du multiplateforme, et il ne coûte qu'une lecture : un abonnement pris
 * sur l'iPhone se gère dans les réglages d'Apple, un abonnement pris sur le web se gère chez
 * Stripe. Un bouton qui ouvre le mauvais donne un écran vide et un message au support.
 */
export async function manageSubscription(): Promise<CheckoutResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const right = await readEntitlement();

  if (!entitlement.isPaid(right)) {
    return { status: "error", message: "Tu n'as pas d'abonnement en cours." };
  }

  if (right.store === "app_store") {
    return {
      status: "redirect",
      url: "https://apps.apple.com/account/subscriptions",
    };
  }

  if (right.store === "play_store") {
    return { status: "redirect", url: "https://play.google.com/store/account/subscriptions" };
  }

  // Un abonnement offert n'a pas de portail : il n'y a rien à résilier, et ouvrir un portail
  // vide se lit comme une panne.
  if (right.store === "promotional") {
    return { status: "error", message: "Cet accès a été offert : il n'y a rien à gérer." };
  }

  const key = stripeKey();
  if (!key) return { status: "unavailable", message: "Le portail n'est pas encore branché." };

  const email = user?.email;
  if (!email) {
    return { status: "error", message: "Aucune adresse rattachée à ce compte." };
  }

  // **Le client Stripe se retrouve par son adresse.** On ne garde pas son `cus_…` : la table
  // `entitlements` n'a qu'une plume, le webhook RevenueCat, et il ne transporte pas ce champ.
  // Ajouter une colonne que personne n'écrit serait une colonne qui mentira.
  const customerId = await findStripeCustomer(key, email);
  if (!customerId) {
    return {
      status: "error",
      message: "Cet abonnement n'a pas été pris sur le web. Gère-le depuis l'appareil d'achat.",
    };
  }

  const response = await fetch("https://api.stripe.com/v1/billing_portal/sessions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      customer: customerId,
      return_url: checkoutReturnUrl(SITE_URL, "/app/reglages"),
      locale: "fr",
    }),
  });

  if (!response.ok) {
    const payload: unknown = await response.json().catch(() => null);
    console.error("stripe.portal", response.status, extractStripeMessage(payload));
    return {
      status: "error",
      message: stripeRefusalMessage(response.status, payload, "Portail"),
    };
  }

  const session = (await response.json()) as { url?: string };
  if (!session.url) return { status: "error", message: "Stripe n'a pas rendu de portail." };

  return { status: "redirect", url: session.url };
}

/** Le `cus_…` d'une adresse, ou `null` si Stripe ne connaît personne sous ce courriel. */
async function findStripeCustomer(key: string, email: string): Promise<string | null> {
  const query = new URLSearchParams({ email, limit: "1" });
  const response = await fetch(`https://api.stripe.com/v1/customers?${query}`, {
    headers: { Authorization: `Bearer ${key}` },
  });

  if (!response.ok) return null;

  const payload = (await response.json()) as { data?: { id?: string }[] };
  return payload.data?.[0]?.id ?? null;
}
