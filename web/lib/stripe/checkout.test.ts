import { describe, expect, it } from "vitest";

import {
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
    expect(priceIdProblem("price_1UA59JQMgx8zg1703xvj1Cgk")).toBeNull();
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
