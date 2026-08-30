import type { pricing } from "@micabo/core";

/**
 * Le corps et les refus de Checkout, hors réseau.
 *
 * `startCheckout` avalait le JSON de Stripe et n'affichait que le statut. Un
 * 400 « Offre : Hebdomadaire » ne dit pas si le `price_…` est inconnu, si
 * l'e-mail est vide, ou si le tarif n'est pas récurrent. Ici, le message
 * Stripe est lu, et les champs vides ne partent plus.
 */

export function envOrCatalogPrice(
  fromEnv: string | undefined,
  fallback: string,
): string {
  const trimmed = fromEnv?.trim();
  return trimmed ? trimmed : fallback;
}

export function priceIdFor(
  plan: pricing.CatalogPlan,
  env: { yearly?: string; weekly?: string; yearlyDiscount?: string },
  catalog: (plan: pricing.CatalogPlan) => string,
): string {
  if (plan === "yearly") return envOrCatalogPrice(env.yearly, catalog("yearly"));
  if (plan === "yearly_discount") {
    return envOrCatalogPrice(env.yearlyDiscount, catalog("yearly_discount"));
  }
  return envOrCatalogPrice(env.weekly, catalog("weekly"));
}

/** Un identifiant Apple, un `prod_…`, une chaîne vide : Stripe rend 400. */
export function priceIdProblem(id: string): string | null {
  if (!id) return "Le tarif Stripe n'est pas renseigné.";
  if (id.startsWith("prod_")) {
    return "C'est un identifiant de produit (prod_…), pas un prix (price_…).";
  }
  if (id.startsWith("com.")) {
    return "C'est l'identifiant Apple. Le checkout web attend un price_… Stripe.";
  }
  if (!/^price_[A-Za-z0-9]+$/.test(id)) {
    return "Le tarif Stripe doit commencer par price_.";
  }
  return null;
}

export function checkoutReturnUrl(base: string, path: string): string {
  const trimmed = base.trim().replace(/\/$/, "");
  const withProtocol = /^https?:\/\//i.test(trimmed) ? trimmed : `https://${trimmed}`;
  const suffix = path.startsWith("/") ? path : `/${path}`;
  return `${withProtocol}${suffix}`;
}

export function checkoutSessionFields(input: {
  price: string;
  userId: string;
  email?: string | null;
  trialDays: number;
  successUrl: string;
  cancelUrl: string;
}): Record<string, string> {
  const fields: Record<string, string> = {
    mode: "subscription",
    "line_items[0][price]": input.price,
    "line_items[0][quantity]": "1",
    // Stripe rend cet identifiant à RevenueCat, qui le pose en app_user_id.
    client_reference_id: input.userId,
    success_url: input.successUrl,
    cancel_url: input.cancelUrl,
    locale: "fr",
  };

  const email = input.email?.trim();
  if (email) fields.customer_email = email;
  if (input.trialDays > 0) {
    fields["subscription_data[trial_period_days]"] = String(input.trialDays);
  }

  return fields;
}

export function extractStripeMessage(payload: unknown): string {
  if (!payload || typeof payload !== "object") return "";
  const error = (payload as { error?: { message?: unknown } }).error;
  if (typeof error?.message === "string") return error.message.trim();
  return "";
}

export function stripeRefusalMessage(
  status: number,
  payload: unknown,
  offerTitle: string,
): string {
  const raw = extractStripeMessage(payload);

  if (/no such price/i.test(raw)) {
    return `Stripe ne connaît pas le tarif « ${offerTitle} ». Le price_… doit être celui du même compte et du même mode (test ou live) que la clé secrète.`;
  }
  if (/type=recurring|one_time/i.test(raw)) {
    return `Le tarif « ${offerTitle} » n'est pas un abonnement récurrent. Dans Stripe, choisis Recurring — Weekly, pas One time.`;
  }
  if (/customer_email/i.test(raw) && /empty|invalid|blank/i.test(raw)) {
    return "Ton compte n'a pas d'adresse e-mail reconnue. Reconnecte-toi, puis réessaie.";
  }
  if (/success_url|cancel_url|invalid url/i.test(raw)) {
    return "Stripe a refusé l'adresse de retour. NEXT_PUBLIC_SITE_URL doit être une URL https complète.";
  }
  if (/customer portal/i.test(raw)) {
    return "Le portail client Stripe n'est pas activé. Dashboard → Settings → Billing → Customer portal.";
  }
  if (raw) return raw;
  return `Stripe a refusé (${status}). Offre : ${offerTitle}.`;
}
