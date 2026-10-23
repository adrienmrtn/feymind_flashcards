import { describe, expect, it } from "vitest";

import {
  FAILURE_TTL_MS,
  NEGATIVE_TTL_MS,
  createProLookup,
  proFromSubscriber,
  revenueCatKey,
} from "./revenuecat";

const now = Date.parse("2026-10-23T12:00:00Z");

const playSubscriber = {
  subscriber: {
    entitlements: {
      pro: {
        expires_date: "2027-10-23T12:00:00Z",
        product_identifier: "com.micabo.app.pro.yearly",
      },
    },
    subscriptions: {
      "com.micabo.app.pro.yearly": {
        store: "play_store",
        period_type: "normal",
        unsubscribe_detected_at: null,
        billing_issues_detected_at: null,
      },
    },
  },
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status });
}

describe("proFromSubscriber", () => {
  it("reconnaît un abonné Google Play que la table ignore", () => {
    expect(proFromSubscriber(playSubscriber, now)).toEqual({
      isPro: true,
      productId: "com.micabo.app.pro.yearly",
      store: "play_store",
      periodType: "normal",
      expiresAt: new Date("2027-10-23T12:00:00Z"),
      willRenew: true,
    });
  });

  it("ne compte ni un droit expiré, ni un droit absent", () => {
    expect(
      proFromSubscriber({ subscriber: { entitlements: { pro: { expires_date: "2026-10-01T00:00:00Z" } } } }, now),
    ).toBeNull();
    expect(proFromSubscriber({ subscriber: { entitlements: {} } }, now)).toBeNull();
    expect(proFromSubscriber(null, now)).toBeNull();
  });

  it("ramène Stripe et RC Billing au même magasin", () => {
    const body = structuredClone(playSubscriber);
    body.subscriber.subscriptions["com.micabo.app.pro.yearly"].store = "rc_billing";
    expect(proFromSubscriber(body, now)?.store).toBe("stripe");
  });
});

describe("revenueCatKey", () => {
  it("préfère la clé secrète, puis la publique, puis celle de l'app", () => {
    expect(revenueCatKey({ REVENUECAT_SECRET_KEY: " sk_x ", REVENUECAT_PUBLIC_KEY: "appl_y" })).toBe("sk_x");
    expect(revenueCatKey({ REVENUECAT_PUBLIC_KEY: "appl_y" })).toBe("appl_y");
    expect(revenueCatKey({})).toMatch(/^appl_/);
  });

  it("se coupe par REVENUECAT_WEB_FALLBACK=off", () => {
    expect(revenueCatKey({ REVENUECAT_WEB_FALLBACK: "off", REVENUECAT_SECRET_KEY: "sk_x" })).toBeNull();
  });
});

describe("createProLookup", () => {
  it("ne demande qu'une fois par compte tant que la réponse vaut", async () => {
    let calls = 0;
    let clock = now;
    const lookup = createProLookup({
      key: () => "sk_test",
      now: () => clock,
      fetch: async () => {
        calls += 1;
        return json({ subscriber: { entitlements: {} } });
      },
    });

    expect(await lookup("user-1")).toBeNull();
    expect(await lookup("user-1")).toBeNull();
    expect(calls).toBe(1);

    clock += NEGATIVE_TTL_MS + 1;
    await lookup("user-1");
    expect(calls).toBe(2);
  });

  it("rend Pro, et une panne n'est qu'un « je ne sais pas » vite redemandé", async () => {
    let calls = 0;
    let clock = now;
    let failing = true;
    const lookup = createProLookup({
      key: () => "sk_test",
      now: () => clock,
      fetch: async () => {
        calls += 1;
        if (failing) throw new Error("timeout");
        return json(playSubscriber);
      },
    });

    expect(await lookup("user-2")).toBeNull();
    failing = false;
    clock += FAILURE_TTL_MS + 1;
    expect((await lookup("user-2"))?.store).toBe("play_store");
    expect(calls).toBe(2);
  });

  it("ne demande rien quand la relecture est coupée", async () => {
    let calls = 0;
    const lookup = createProLookup({
      key: () => null,
      fetch: async () => {
        calls += 1;
        return json(playSubscriber);
      },
    });
    expect(await lookup("user-3")).toBeNull();
    expect(calls).toBe(0);
  });

  it("envoie la clé, et l'identifiant du compte dans l'adresse", async () => {
    const seen: { url: string; auth: string | null }[] = [];
    const lookup = createProLookup({
      key: () => "sk_test",
      now: () => now,
      fetch: async (url, init) => {
        seen.push({ url, auth: new Headers(init.headers).get("Authorization") });
        return json(playSubscriber);
      },
    });
    await lookup("8f1c2c9e-0000-4000-8000-000000000000");
    expect(seen).toEqual([
      {
        url: "https://api.revenuecat.com/v1/subscribers/8f1c2c9e-0000-4000-8000-000000000000",
        auth: "Bearer sk_test",
      },
    ]);
  });
});
