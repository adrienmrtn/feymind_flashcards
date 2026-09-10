import { describe, expect, it } from "vitest";

import { pricing } from "@micabo/core";

import { checkoutNote } from "../pricing-copy";
import {
  checkoutIdempotencyKey,
  checkoutReturnUrl,
  checkoutSessionFields,
  envOrCatalogPrice,
  extractStripeMessage,
  priceIdFor,
  priceIdProblem,
  stripeRefusalMessage,
} from "./checkout";

describe("envOrCatalogPrice", () => {
  it("laisse l'env gagner, et ignore une chaîne vide", () => {
    expect(envOrCatalogPrice("price_from_env", "price_catalog")).toBe("price_from_env");
    expect(envOrCatalogPrice("  price_from_env  ", "price_catalog")).toBe("price_from_env");
    expect(envOrCatalogPrice("", "price_catalog")).toBe("price_catalog");
    expect(envOrCatalogPrice("   ", "price_catalog")).toBe("price_catalog");
    expect(envOrCatalogPrice(undefined, "price_catalog")).toBe("price_catalog");
  });
});

describe("priceIdFor", () => {
  const catalog = (plan: "yearly" | "weekly" | "yearly_discount") =>
    plan === "yearly" ? "price_year" : plan === "weekly" ? "price_week" : "price_discount";

  it("prend le weekly d'env, pas le catalogue, dès qu'il est posé", () => {
    expect(
      priceIdFor("weekly", { yearly: "price_y", weekly: "price_w" }, catalog),
    ).toBe("price_w");
  });

  it("ne laisse pas un STRIPE_PRICE_WEEKLY vide masquer le catalogue", () => {
    expect(priceIdFor("weekly", { weekly: "" }, catalog)).toBe("price_week");
  });

  it("sert le tarif réduit, par env puis par catalogue", () => {
    expect(priceIdFor("yearly_discount", { yearlyDiscount: "price_d" }, catalog)).toBe("price_d");
    expect(priceIdFor("yearly_discount", {}, catalog)).toBe("price_discount");
  });
});

describe("priceIdProblem", () => {
  it("accepte un price_…", () => {
    expect(priceIdProblem("price_1UAqBI47TFrcO0lvTLjtkffx")).toBeNull();
  });

  it("refuse un identifiant Apple, un prod_…, ou le vide", () => {
    expect(priceIdProblem("com.micabo.app.pro.weekly")).toMatch(/Apple/);
    expect(priceIdProblem("prod_abc")).toMatch(/prod_/);
    expect(priceIdProblem("")).toMatch(/pas renseigné/);
    expect(priceIdProblem("weekly")).toMatch(/price_/);
  });
});

describe("checkoutSessionFields", () => {
  it("n'envoie pas un customer_email vide — Stripe rend 400", () => {
    const fields = checkoutSessionFields({
      price: "price_week",
      userId: "user-1",
      email: "",
      trialDays: 0,
      successUrl: "https://micabo.app/app?abonnement=ok",
      cancelUrl: "https://micabo.app/app",
    });
    expect(fields.customer_email).toBeUndefined();
    expect(fields["subscription_data[trial_period_days]"]).toBeUndefined();
    expect(fields["line_items[0][price]"]).toBe("price_week");
    expect(fields["metadata[supabase_user_id]"]).toBe("user-1");
    expect(fields["subscription_data[metadata][supabase_user_id]"]).toBe("user-1");
  });

  it("pose une clé d'idempotence stable sur l'heure", () => {
    const now = Date.parse("2026-08-31T16:10:00Z");
    expect(checkoutIdempotencyKey("user-1", "weekly", now)).toBe(
      checkoutIdempotencyKey("user-1", "weekly", now + 60_000),
    );
    expect(checkoutIdempotencyKey("user-1", "weekly", now)).not.toBe(
      checkoutIdempotencyKey("user-1", "yearly", now),
    );
    expect(checkoutIdempotencyKey("user-1", "weekly", now, "EUR")).not.toBe(
      checkoutIdempotencyKey("user-1", "weekly", now, "TRY"),
    );
  });

  it("pose l'essai seulement quand il y en a un", () => {
    const yearly = checkoutSessionFields({
      price: "price_year",
      userId: "user-1",
      email: "a@b.c",
      trialDays: 3,
      successUrl: "https://micabo.app/ok",
      cancelUrl: "https://micabo.app",
    });
    expect(yearly.customer_email).toBe("a@b.c");
    expect(yearly["subscription_data[trial_period_days]"]).toBe("3");
    // Plus de locale par défaut : « en » écrit en dur servait des pages anglaises à des
    // gens qui payaient en livres. Sans le champ, Stripe lit l'en-tête du navigateur.
    expect(yearly.locale).toBeUndefined();
  });

  it("écrit notre phrase au-dessus du bouton, et rien quand on n'a rien à dire", () => {
    const withNote = checkoutSessionFields({
      price: "price_year",
      userId: "user-1",
      trialDays: 3,
      successUrl: "https://micabo.app/ok",
      cancelUrl: "https://micabo.app",
      note: "Micabo Pro · 3 gün ücretsiz, sonra yılda 3.899,99 ₺.",
    });
    expect(withNote["custom_text[submit][message]"]).toBe(
      "Micabo Pro · 3 gün ücretsiz, sonra yılda 3.899,99 ₺.",
    );

    const silent = checkoutSessionFields({
      price: "price_year",
      userId: "user-1",
      trialDays: 0,
      successUrl: "https://micabo.app/ok",
      cancelUrl: "https://micabo.app",
      note: "   ",
    });
    expect(silent["custom_text[submit][message]"]).toBeUndefined();
  });

  it("tronque la phrase à la limite de Stripe plutôt que de se faire refuser", () => {
    const fields = checkoutSessionFields({
      price: "price_year",
      userId: "user-1",
      trialDays: 0,
      successUrl: "https://micabo.app/ok",
      cancelUrl: "https://micabo.app",
      note: "a".repeat(1500),
    });
    expect(fields["custom_text[submit][message]"]).toHaveLength(1200);
  });

  it("décline Managed Payments, qui refuse la phrase et rendait 400 à chaque checkout", () => {
    const fields = checkoutSessionFields({
      price: "price_year",
      userId: "user-1",
      trialDays: 0,
      successUrl: "https://micabo.app/ok",
      cancelUrl: "https://micabo.app",
      note: "Micabo Pro · 3 gün ücretsiz, sonra yılda 3.899,99 ₺.",
    });
    // À chaque requête, phrase ou non : le résultat ne doit pas dépendre d'un réglage Stripe.
    expect(fields["managed_payments[enabled]"]).toBe("false");
  });

  it("dit la langue et la devise plutôt que de les laisser deviner", () => {
    // Sans `currency`, Checkout la déduit de l'adresse IP : un Turc en
    // déplacement paierait des euros après avoir lu des livres.
    const fields = checkoutSessionFields({
      price: "price_year",
      userId: "user-1",
      trialDays: 0,
      successUrl: "https://micabo.app/ok",
      cancelUrl: "https://micabo.app",
      locale: "tr",
      currency: "try",
    });
    expect(fields.locale).toBe("tr");
    expect(fields.currency).toBe("try");
  });

  it("n'envoie pas de devise vide — Stripe la refuserait", () => {
    const fields = checkoutSessionFields({
      price: "price_year",
      userId: "user-1",
      trialDays: 0,
      successUrl: "https://micabo.app/ok",
      cancelUrl: "https://micabo.app",
      currency: "  ",
    });
    expect(fields.currency).toBeUndefined();
  });
});

describe("checkoutReturnUrl", () => {
  it("ajoute https si le protocole manque", () => {
    expect(checkoutReturnUrl("www.micabo.app", "/app")).toBe("https://www.micabo.app/app");
    expect(checkoutReturnUrl("https://www.micabo.app/", "/app")).toBe(
      "https://www.micabo.app/app",
    );
  });
});

describe("stripeRefusalMessage", () => {
  it("lit le message Stripe plutôt qu'un statut nu", () => {
    expect(
      extractStripeMessage({
        error: { message: "No such price: 'price_wrong'" },
      }),
    ).toBe("No such price: 'price_wrong'");
  });

  it("traduit un price inconnu et un tarif one-time", () => {
    expect(
      stripeRefusalMessage(400, { error: { message: "No such price: 'x'" } }, "Hebdomadaire"),
    ).toMatch(/ne connaît pas le tarif « Hebdomadaire »/);
    expect(
      stripeRefusalMessage(
        400,
        {
          error: {
            message:
              "The price specified is set to `type=one_time` but this field only accepts prices with `type=recurring`.",
          },
        },
        "Hebdomadaire",
      ),
    ).toMatch(/pas un abonnement récurrent/);
  });

  it("dit d'activer le portail client", () => {
    expect(
      stripeRefusalMessage(
        400,
        {
          error: {
            message:
              "You cannot create a billing portal session without configuring a customer portal in your settings.",
          },
        },
        "Portail",
      ),
    ).toMatch(/portail client Stripe n'est pas activé/);
  });

  it("garde le repli si Stripe n'a rien dit", () => {
    expect(stripeRefusalMessage(400, {}, "Hebdomadaire")).toBe(
      "Stripe a refusé (400). Offre : Hebdomadaire.",
    );
  });
});

describe("checkoutLocale", () => {
  it("suit le choix, où qu'on se trouve", () => {
    // Qui lit Micabo en français paie en français, même depuis la Turquie : la page
    // Stripe continue la page d'où l'on vient, elle n'en ouvre pas une autre.
    expect(pricing.checkoutLocale({ chosen: "fr", navigator: "tr", country: "tr" })).toBe("fr");
  });

  it("écoute le navigateur quand personne n'a choisi", () => {
    expect(pricing.checkoutLocale({ chosen: null, navigator: "tr", country: "fr" })).toBe("tr");
    expect(pricing.checkoutLocale({ navigator: "es-ES" })).toBe("es");
  });

  it("va chercher le pays plutôt que de retomber sur l'anglais", () => {
    // Les trois sessions perdues : navigateur en une langue qu'on ne parle pas, pays turc,
    // prix en livres — et une page Stripe en anglais.
    expect(pricing.checkoutLocale({ chosen: null, navigator: null, country: "TR" })).toBe("tr");
    expect(pricing.checkoutLocale({ country: "at" })).toBe("de");
    expect(pricing.checkoutLocale({ country: "mx" })).toBe("es");
  });

  it("préfère se taire que d'inventer", () => {
    // Rien de dit, pays qu'on ne sait pas traduire : Stripe lira l'en-tête du navigateur,
    // ce qui reste une meilleure supposition que la nôtre.
    expect(pricing.checkoutLocale({})).toBeUndefined();
    expect(pricing.checkoutLocale({ chosen: "  ", navigator: null, country: "jp" })).toBeUndefined();
  });

  it("laisse la devise décider seule de son côté", () => {
    // Deux règles distinctes, et c'est voulu : un Turc qui lit Micabo en anglais voit une
    // page anglaise, et il paie quand même en livres.
    expect(pricing.checkoutLocale({ navigator: "en", country: "tr" })).toBe("en");
    expect(pricing.presentmentCurrencyFor("en", "tr")).toBe("TRY");
  });
});

describe("checkoutNote", () => {
  const t = ((key: string, vars?: Record<string, string | number>) =>
    `${key}|${JSON.stringify(vars)}`) as Parameters<typeof checkoutNote>[0];

  it("annonce l'essai, puis la somme réellement prélevée", () => {
    const note = checkoutNote(t, pricing.YEARLY, "TRY");
    expect(note).toContain("app.paywall.stripeNote.trialYearly");
    expect(note).toContain('"days":3');
    // Le prix annuel, pas le mensuel équivalent affiché sur la carte : c'est le montant
    // que Stripe va prélever, et l'écart entre les deux est ce qui fait fermer l'onglet.
    expect(note).toContain(pricing.priceText(3899.99, "TRY"));
  });

  it("ne promet pas d'essai là où il n'y en a pas", () => {
    expect(checkoutNote(t, pricing.WEEKLY, "EUR")).toContain("app.paywall.stripeNote.weekly");
    expect(checkoutNote(t, pricing.DISCOUNT_YEARLY, "EUR")).toContain(
      "app.paywall.stripeNote.yearly",
    );
  });
});
