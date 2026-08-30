"use server";

import { entitlement, pricing } from "@micabo/core";

import { SITE_URL } from "@/lib/config";
import { readEntitlement } from "@/lib/data/entitlement";
import { createClient } from "@/lib/supabase/server";

/**
 * L'encaissement, **et il n'est pas branché.**
 *
 * Ce fichier existe pour que le point de raccordement soit écrit, nommé et **fermé par défaut**  - 
 * pas pour prétendre que le paiement marche. Il n'y a pas de clé Stripe, donc il n'y a pas de
 * paiement, et tout ce qui suit le dit franchement plutôt que d'échouer à mi-chemin.
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

/** L'identifiant de prix Stripe. L'env gagne, le catalogue sert de repli. */
function priceId(kind: pricing.PlanKind): string {
  if (kind === "yearly") {
    return process.env.STRIPE_PRICE_YEARLY ?? pricing.stripePriceId("yearly");
  }
  return process.env.STRIPE_PRICE_WEEKLY ?? pricing.stripePriceId("weekly");
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

  if (!key) {
    return {
      status: "unavailable",
      message: "L'abonnement n'est pas encore ouvert.",
    };
  }

  const plan = pricing.planFor(kind);

  const response = await fetch("https://api.stripe.com/v1/checkout/sessions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      mode: "subscription",
      "line_items[0][price]": price,
      "line_items[0][quantity]": "1",
      // C'est **la** ligne qui fait tenir le droit multiplateforme : Stripe rend cet identifiant à
      // RevenueCat, qui le pose en `app_user_id`, qui devient la clé de `entitlements`.
      client_reference_id: user.id,
      customer_email: user.email ?? "",
      ...(pricing.hasTrial(plan)
        ? { "subscription_data[trial_period_days]": String(plan.trialDays) }
        : {}),
      success_url: `${SITE_URL}/app?abonnement=ok`,
      cancel_url: `${SITE_URL}/app`,
      locale: "fr",
      // Une clé d'idempotence par offre et par personne : un double clic ne crée pas deux
      // abonnements.
      // (Stripe la lit dans l'en-tête, posée ci-dessous.)
    }),
  });

  if (!response.ok) {
    return { status: "error", message: `Stripe a refusé (${response.status}). Offre : ${plan.title}.` };
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

  const key = stripeKey();
  if (!key) return { status: "unavailable", message: "Le portail n'est pas encore branché." };

  // Le portail de facturation de Stripe demande l'identifiant du client, que RevenueCat garde.
  // Il se lira dans `entitlements` le jour où le webhook le transportera - il n'y a rien à
  // inventer ici en attendant.
  return { status: "unavailable", message: "Le portail arrive avec le branchement de Stripe." };
}
