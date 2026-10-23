import { describe, expect, it } from "vitest";

import { pricing } from "@micabo/core";

import { checkoutNote } from "../pricing-copy";
import {
  CHECKOUT_MAINTENANCE,
  checkoutIdempotencyKey,
  checkoutReturnUrl,
  checkoutSessionFields,
  extractStripeMessage,
  priceIdFor,
  priceIdProblem,
  stripeRefusalMessage,
} from "./checkout";

describe("CHECKOUT_MAINTENANCE", () => {
  it("le paiement web est fermé : aucune session Stripe ne se crée", () => {
    // Rouvrir le paiement est une décision : elle passe par ce test, pas par un réglage.
    expect(CHECKOUT_MAINTENANCE).toBe(true);
  });
});

describe("priceIdFor", () => {
  const spain = pricing.presentmentFor("es");
  const france = pricing.presentmentFor("fr");
  const mexico = pricing.presentmentFor("mx");

  it("prend le prix du groupe du pays, dans l'environnement", () => {
    const env = {
      STRIPE_PRICE_YEARLY: "price_y",
      STRIPE_PRICE_YEARLY_SOUTH: "price_y_south",
      STRIPE_PRICE_WEEKLY: "price_w",
    };
    expect(priceIdFor("yearly", france, env, pricing.stripePriceIdFromEnv)).toBe("price_y");
    expect(priceIdFor("yearly", spain, env, pricing.stripePriceIdFromEnv)).toBe("price_y_south");
    // Le Mexique paie en pesos, dans les `currency_options` du prix standard.
    expect(priceIdFor("weekly", mexico, env, pricing.stripePriceIdFromEnv)).toBe("price_w");
  });

  it("ne retombe jamais sur un prix de l'ancienne grille", () => {
    // Les `price_…` de `STORE_PRODUCTS` prélèveraient 69,99 € sous un paywall à 49,99 €.
    expect(priceIdFor("weekly", france, { STRIPE_PRICE_WEEKLY: " " }, pricing.stripePriceIdFromEnv)).toBe("");
    expect(priceIdFor("yearly_discount", spain, {}, pricing.stripePriceIdFromEnv)).toBe("");
    expect(priceIdProblem(priceIdFor("yearly", spain, {}, pricing.stripePriceIdFromEnv))).toMatch(
      /pas renseigné/,
    );
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

  it("pose une clé d'idempotence stable sur l'heure, et sur le corps entier", () => {
    const now = Date.parse("2026-08-31T16:10:00Z");
    const base = {
      price: "price_year",
      userId: "user-1",
      trialDays: 0,
      successUrl: "https://micabo.app/ok",
      cancelUrl: "https://micabo.app",
      locale: "fr",
      currency: "eur",
      note: "Micabo Pro · 29,99 € par an.",
    };
    const fr = checkoutSessionFields(base);

    // Un double-clic : le même corps dans la même heure, la même clé.
    expect(checkoutIdempotencyKey(fr, now)).toBe(checkoutIdempotencyKey(fr, now + 60_000));
    expect(checkoutIdempotencyKey(fr, now)).not.toBe(
      checkoutIdempotencyKey(fr, now + 60 * 60_000),
    );

    // Passer le site en espagnol change la locale et la phrase. Stripe refuse une clé
    // réutilisée avec d'autres paramètres : la clé doit donc changer avec eux.
    const es = checkoutSessionFields({
      ...base,
      locale: "es",
      note: "Micabo Pro · 29,99 € al año.",
    });
    expect(checkoutIdempotencyKey(es, now)).not.toBe(checkoutIdempotencyKey(fr, now));

    const weekly = checkoutSessionFields({ ...base, price: "price_week" });
    expect(checkoutIdempotencyKey(weekly, now)).not.toBe(checkoutIdempotencyKey(fr, now));

    const lira = checkoutSessionFields({ ...base, currency: "try" });
    expect(checkoutIdempotencyKey(lira, now)).not.toBe(checkoutIdempotencyKey(fr, now));

    // Lisible dans les journaux Stripe, et loin de la limite de 255 caractères.
    expect(checkoutIdempotencyKey(fr, now)).toMatch(/^checkout-user-1-\d+-[0-9a-f]{32}$/);
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
    expect(pricing.checkoutLocale({ country: "mx" })).toBe("es-419");
    expect(pricing.checkoutLocale({ country: "br" })).toBe("pt-BR");
    expect(pricing.checkoutLocale({ country: "pl" })).toBe("pl");
  });

  it("garde les variantes régionales que Stripe sait afficher", () => {
    expect(pricing.checkoutLocale({ chosen: "pt-BR" })).toBe("pt-BR");
    expect(pricing.checkoutLocale({ chosen: "es-419" })).toBe("es-419");
    expect(pricing.checkoutLocale({ chosen: "pt" })).toBe("pt");
    expect(pricing.checkoutLocale({ navigator: "fr-CA" })).toBe("fr");
  });

  it("se tait sur une langue que Stripe n'affiche pas, plutôt que d'en changer", () => {
    // Une locale inconnue de Stripe fait refuser la session : l'arabe et le serbe n'y sont pas.
    expect(pricing.checkoutLocale({ chosen: "ar", country: "fr" })).toBeUndefined();
    expect(pricing.checkoutLocale({ chosen: "sr" })).toBeUndefined();
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
    expect(pricing.checkoutCurrency(pricing.presentmentFor("tr", "en"))).toBe("try");
  });
});

describe("checkoutNote", () => {
  const t = ((key: string, vars?: Record<string, string | number>) =>
    `${key}|${JSON.stringify(vars)}`) as Parameters<typeof checkoutNote>[0];

  it("annonce l'essai, puis la somme réellement prélevée", () => {
    const turkey = pricing.presentmentFor("tr", "tr");
    const note = checkoutNote(t, pricing.YEARLY, turkey);
    expect(note).toContain("app.paywall.stripeNote.trialYearly");
    expect(note).toContain('"days":3');
    // Le prix annuel, pas le mensuel équivalent affiché sur la carte : c'est le montant
    // que Stripe va prélever, et l'écart entre les deux est ce qui fait fermer l'onglet.
    expect(note).toContain(pricing.priceText(1499.99, turkey));
  });

  it("annonce l'essai de l'hebdomadaire, comme l'app", () => {
    const italy = pricing.presentmentFor("it", "it");
    const note = checkoutNote(t, pricing.WEEKLY, italy);
    expect(note).toContain("app.paywall.stripeNote.trialWeekly");
    // L'Italie paie 3,99 € la semaine, comme dans l'app.
    expect(note).toContain(pricing.priceText(3.99, italy));
  });

  it("ne promet pas d'essai là où il n'y en a pas", () => {
    expect(checkoutNote(t, pricing.DISCOUNT_YEARLY, pricing.DEFAULT_PRESENTMENT)).toContain(
      "app.paywall.stripeNote.yearly",
    );
  });
});
