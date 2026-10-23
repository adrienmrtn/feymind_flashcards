import assert from "node:assert/strict";
import { it } from "node:test";
import {
  type AccessRow,
  activeProFrom,
  needsRevenueCatRecheck,
  reconcileAccess,
  resolveEventAccess,
  syncEventId,
  transferTargets,
  wasApplied,
} from "./revenuecat.ts";

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

it("chaque recopie porte son propre identifiant d'événement", () => {
  // Un identifiant fixe tombait sur l'index unique `entitlements_event_id_key` dès le
  // deuxième compte : `apply_entitlement` l'ignorait, et plus personne n'était recopié.
  const a = syncEventId("11111111-1111-1111-1111-111111111111", now);
  const b = syncEventId("22222222-2222-2222-2222-222222222222", now);
  const later = syncEventId("11111111-1111-1111-1111-111111111111", now + 1);
  assert.notEqual(a, b);
  assert.notEqual(a, later);
  assert.notEqual(a, "revenuecat-sync");
  assert.ok(a.startsWith("revenuecat-sync-"));
});

it("ne compte une recopie que si la base l'a appliquée", () => {
  assert.equal(wasApplied([{ applied: true, is_pro: true }]), true);
  assert.equal(wasApplied([{ applied: false, is_pro: false }]), false);
  assert.equal(wasApplied([]), false);
  assert.equal(wasApplied(null), false);
  assert.equal(wasApplied({ applied: true }), true);
  assert.equal(wasApplied([{ applied: "true" }]), false);
});

const GUEST = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const ACCOUNT = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";

it("un transfert de l'invité vers le compte se lit sans app_user_id", () => {
  assert.deepEqual(
    transferTargets({ transferred_from: [GUEST], transferred_to: [ACCOUNT] }),
    { to: [ACCOUNT], from: [GUEST] },
  );
});

it("un transfert ignore les identifiants anonymes et ce qui n'est pas une liste", () => {
  assert.deepEqual(
    transferTargets({
      transferred_from: ["$RCAnonymousID:abc", GUEST],
      transferred_to: [ACCOUNT.toUpperCase(), 42],
    }),
    { to: [ACCOUNT], from: [GUEST] },
  );
  assert.deepEqual(transferTargets({ transferred_to: "nope" }), { to: [], from: [] });
  assert.deepEqual(transferTargets({}), { to: [], from: [] });
});

it("un app_user_id présent reçoit, sauf s'il est parmi ceux qui perdent", () => {
  assert.deepEqual(
    transferTargets({ app_user_id: ACCOUNT, transferred_from: [GUEST] }),
    { to: [ACCOUNT], from: [GUEST] },
  );
  assert.deepEqual(
    transferTargets({ app_user_id: GUEST, transferred_from: [GUEST], transferred_to: [ACCOUNT] }),
    { to: [ACCOUNT], from: [GUEST] },
  );
  // Des deux côtés à la fois : il reçoit, on ne le ferme pas.
  assert.deepEqual(
    transferTargets({ transferred_from: [ACCOUNT, GUEST], transferred_to: [ACCOUNT] }),
    { to: [ACCOUNT], from: [GUEST] },
  );
});

// MARK: - Ce qu'un événement du webhook dit de l'accès

it("une pause programmée garde l'accès jusqu'à l'échéance, sans renouvellement", () => {
  // Google Play annonce la pause quand l'abonné la programme ; elle ne commence qu'à la fin
  // de la période payée, avec son `EXPIRATION`. Fermer ici retirait des jours payés.
  assert.deepEqual(resolveEventAccess({ type: "SUBSCRIPTION_PAUSED" }), {
    isPro: true,
    willRenew: false,
  });
});

it("l'expiration ferme, la résiliation et l'incident de paiement non", () => {
  assert.deepEqual(resolveEventAccess({ type: "EXPIRATION" }), { isPro: false, willRenew: false });
  assert.deepEqual(resolveEventAccess({ type: "CANCELLATION" }), { isPro: true, willRenew: false });
  assert.deepEqual(resolveEventAccess({ type: "BILLING_ISSUE" }), { isPro: true, willRenew: false });
  assert.deepEqual(resolveEventAccess({ type: "renewal" }), { isPro: true, willRenew: true });
});

it("un événement qui ne concerne pas le droit pro, ou inconnu, ne touche à rien", () => {
  assert.equal(resolveEventAccess({ type: "EXPIRATION", entitlement_ids: ["autre"] }), null);
  assert.equal(resolveEventAccess({ type: "TEST" }), null);
  assert.equal(resolveEventAccess({}), null);
});

it("seuls les événements qui retirent quelque chose relisent RevenueCat", () => {
  for (
    const type of ["EXPIRATION", "cancellation", "SUBSCRIPTION_PAUSED", "BILLING_ISSUE", "REFUND", "REVOKED"]
  ) {
    assert.equal(needsRevenueCatRecheck(type), true, type);
  }
  for (const type of ["INITIAL_PURCHASE", "RENEWAL", "TRANSFER", "TEST", undefined]) {
    assert.equal(needsRevenueCatRecheck(type), false, String(type));
  }
});

const expiringAppStore: AccessRow = {
  isPro: false,
  willRenew: false,
  productId: "com.micabo.app.pro.monthly",
  store: "app_store",
  periodType: "normal",
  expiresAt: "2026-10-16T11:00:00.000Z",
};

it("l'expiration d'un magasin ne ferme pas un abonnement actif dans l'autre", () => {
  const playStore = {
    productId: "micabo_pro_annual",
    store: "play_store",
    periodType: "normal",
    expiresAt: "2027-10-01T00:00:00Z",
    willRenew: true,
  };
  assert.deepEqual(reconcileAccess(expiringAppStore, playStore), {
    isPro: true,
    willRenew: true,
    productId: "micabo_pro_annual",
    store: "play_store",
    periodType: "normal",
    expiresAt: "2027-10-01T00:00:00Z",
  });
});

it("sans droit actif chez RevenueCat, l'événement fait foi", () => {
  assert.deepEqual(reconcileAccess(expiringAppStore, null), expiringAppStore);
});

it("une résiliation recopie l'échéance du droit qui court encore", () => {
  // Le mensuel résilié expire demain, l'annuel pris à côté court un an : la ligne ne doit pas
  // se fermer demain.
  const cancelled: AccessRow = {
    ...expiringAppStore,
    isPro: true,
    expiresAt: "2026-10-17T00:00:00.000Z",
  };
  const annual = {
    productId: "com.micabo.app.pro.annual",
    store: "app_store",
    periodType: "normal",
    expiresAt: "2027-10-16T00:00:00Z",
    willRenew: true,
  };
  const row = reconcileAccess(cancelled, annual);
  assert.equal(row.isPro, true);
  assert.equal(row.expiresAt, "2027-10-16T00:00:00Z");
  assert.equal(row.productId, "com.micabo.app.pro.annual");
});
