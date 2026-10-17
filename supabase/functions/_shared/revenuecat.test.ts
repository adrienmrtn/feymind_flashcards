import assert from "node:assert/strict";
import { it } from "node:test";
import { activeProFrom } from "./revenuecat.ts";

const now = Date.parse("2026-10-16T12:00:00Z");

it("un essai en cours compte comme Pro", () => {
  const access = activeProFrom({
    subscriber: {
      entitlements: {
        pro: {
          expires_date: "2026-10-19T12:00:00Z",
          product_identifier: "com.micabo.app.pro.weekly",
        },
      },
      subscriptions: {
        "com.micabo.app.pro.weekly": {
          store: "app_store",
          period_type: "trial",
          unsubscribe_detected_at: null,
        },
      },
    },
  }, now);
  assert.deepEqual(access, {
    productId: "com.micabo.app.pro.weekly",
    store: "app_store",
    periodType: "trial",
    expiresAt: "2026-10-19T12:00:00Z",
    willRenew: true,
  });
});

it("un droit expiré ou absent ne compte pas", () => {
  assert.deepEqual(
    activeProFrom({
      subscriber: { entitlements: { pro: { expires_date: "2026-10-01T00:00:00Z" } } },
    }, now),
    null,
  );
  assert.deepEqual(activeProFrom({ subscriber: { entitlements: {} } }, now), null);
  assert.deepEqual(activeProFrom(null, now), null);
});

it("un droit à vie n'a pas de date de fin", () => {
  const access = activeProFrom({
    subscriber: { entitlements: { pro: { expires_date: null, product_identifier: "x" } } },
  }, now);
  assert.deepEqual(access?.expiresAt, null);
});
