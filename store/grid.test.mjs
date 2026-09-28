/**
 * La grille se vérifie sans réseau : `node --test store/`.
 *
 * Ce qu'on fige ici, ce sont les promesses que l'app imprime à côté des prix — « −81 % »,
 * « −40 % », « 3 jours gratuits » — et le fait que le repli écrit dans `PaywallCatalog.swift`
 * soit bien la ligne française de la grille.
 */

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { test } from "node:test";
import {
  currentPrice,
  dayAfter,
  derivationFor,
  discountPercent,
  earliestDateFrom,
  isActiveOffer,
  latestPrice,
  loadGrid,
  pickPricePoint,
  planKeys,
  priceStartDate,
  repoRoot,
  ruleFor,
  savingsPercent,
  validateGrid,
} from "./lib/grid.mjs";
import { credentialProblems, makeToken, readPrivateKey } from "./lib/asc.mjs";
import { generateKeyPairSync, verify } from "node:crypto";

const grid = loadGrid();
const pricedTiers = [grid.base, ...grid.tiers.filter((tier) => tier.rule !== "equalize")];

test("la grille est cohérente", () => {
  assert.deepEqual(validateGrid(grid), []);
  assert.deepEqual(planKeys(grid), ["weekly", "yearly", "discount"]);
});

test("le tarif réduit fait −40 % sur l'annuel, dans chaque palier", () => {
  // Le sceau du cadeau se calcule sur les prix du pays : il doit dire la même remise partout.
  for (const tier of pricedTiers) {
    assert.equal(discountPercent(tier.prices), 40, tier.label);
  }
});

test("l'annuel vaut dix hebdomadaires, sauf aux États-Unis", () => {
  // Aux États-Unis l'hebdomadaire est cher ($7.99) et l'annuel reste au prix du marché
  // ($59.99) : la remise y est plus forte. Partout ailleurs, le même « −80/81 % ».
  for (const tier of pricedTiers) {
    const percent = savingsPercent(tier.prices);
    if (tier.territories?.includes("USA")) {
      assert.equal(percent, 86, tier.label);
    } else {
      assert.ok(percent === 80 || percent === 81, `${tier.label} : −${percent} %`);
    }
  }
});

test("l'hebdomadaire et l'annuel ont trois jours offerts, le tarif réduit aucun", () => {
  assert.equal(grid.products.weekly.trial, "THREE_DAYS");
  assert.equal(grid.products.yearly.trial, "THREE_DAYS");
  assert.equal(grid.products.discount.trial, null);
});

test("le repli de l'app est la ligne française de la grille", () => {
  const swift = readFileSync(resolve(repoRoot, "Micabo/Features/Paywall/PaywallCatalog.swift"), "utf8");
  const declared = (name) => {
    const block = swift.match(new RegExp(`static let ${name} = PaywallPlan\\(([\\s\\S]*?)\\n    \\)`));
    assert.ok(block, `PaywallCatalog.${name} introuvable`);
    return {
      productID: block[1].match(/productID: "([^"]+)"/)[1],
      price: block[1].match(/price: ([\d.]+)/)[1],
    };
  };
  const swiftName = { weekly: "weekly", yearly: "yearly", discount: "discount" };
  for (const key of planKeys(grid)) {
    const plan = declared(swiftName[key]);
    assert.equal(plan.productID, grid.products[key].productId, key);
    assert.equal(Number(plan.price), Number(grid.base.prices[key]), `${key} : Swift ${plan.price}, grille ${grid.base.prices[key]}`);
  }

  const storekit = JSON.parse(readFileSync(resolve(repoRoot, "Micabo/Resources/Micabo.storekit"), "utf8"));
  for (const sub of storekit.subscriptionGroups[0].subscriptions) {
    const key = planKeys(grid).find((k) => grid.products[k].productId === sub.productID);
    assert.equal(Number(sub.displayPrice), Number(grid.base.prices[key]), `Micabo.storekit ${key}`);
    assert.equal(Boolean(sub.introductoryOffer), Boolean(grid.products[key].trial), `essai ${key} dans Micabo.storekit`);
  }
});

test("chaque pays trouve sa règle, et les pays non nommés suivent la France", () => {
  assert.equal(ruleFor(grid, "FRA").base, true);
  assert.equal(ruleFor(grid, "TUR").prices.weekly, "149.99");
  assert.equal(ruleFor(grid, "CAN").from, "USA");
  assert.equal(ruleFor(grid, "POL").from, "ESP");
  assert.equal(ruleFor(grid, "MAR").rule, "usd");
  const other = ruleFor(grid, "GBR");
  assert.equal(other.rule, "equalize");
  assert.equal(other.from, "FRA");
});

test("un pays nommé deux fois est refusé", () => {
  const broken = structuredClone(grid);
  broken.tiers[0].territories.push("TUR");
  assert.ok(validateGrid(broken).some((p) => p.includes("TUR")));
  assert.throws(() => ruleFor(broken, "TUR"));
});

test("le palier exact d'abord, le plus proche avec un avertissement, jamais un palier lointain", () => {
  const points = ["139.99", "149.99", "159.99"].map((customerPrice, i) => ({ id: `p${i}`, customerPrice }));
  assert.equal(pickPricePoint(points, "149.99").point.id, "p1");
  assert.equal(pickPricePoint(points, "149.99").warning, null);

  const near = pickPricePoint(points, "150");
  assert.equal(near.point.id, "p1");
  assert.match(near.warning, /149.99/);

  assert.ok(pickPricePoint(points, "499.99").error);
  // Le peso s'écrit sans centimes chez nous, avec chez Apple.
  assert.equal(pickPricePoint([{ id: "m", customerPrice: "59.00" }], "59").exact, true);
});

test("le prix en vigueur est le dernier commencé, pas un prix à venir", () => {
  const prices = [
    { startDate: null, pointId: "old" },
    { startDate: "2026-09-01", pointId: "now" },
    { startDate: "2099-01-01", pointId: "later" },
    { startDate: "2026-09-10", pointId: "monthly", planType: "MONTHLY" },
  ];
  assert.equal(currentPrice(prices, "2026-09-28").pointId, "now");
  assert.equal(currentPrice([], "2026-09-28"), null);
});

test("une offre finie ne compte plus", () => {
  assert.equal(isActiveOffer({ endDate: null }, "2026-09-28"), true);
  assert.equal(isActiveOffer({ endDate: "2026-01-01" }, "2026-09-28"), false);
});

test("le jeton App Store Connect est un ES256 valide", () => {
  const { privateKey, publicKey } = generateKeyPairSync("ec", { namedCurve: "P-256" });
  const pem = privateKey.export({ type: "pkcs8", format: "pem" });
  // Un secret GitHub arrive souvent aplati : les deux formes doivent se lire.
  const flattened = pem.replace(/\n/g, "\\n");
  const token = makeToken({ keyId: "KEY", issuerId: "ISSUER", privateKey: readPrivateKey(flattened), now: 1000 });

  const [header, payload, signature] = token.split(".");
  assert.deepEqual(JSON.parse(Buffer.from(header, "base64url")), { alg: "ES256", kid: "KEY", typ: "JWT" });
  const claims = JSON.parse(Buffer.from(payload, "base64url"));
  assert.equal(claims.aud, "appstoreconnect-v1");
  assert.equal(claims.iss, "ISSUER");
  assert.ok(claims.exp - claims.iat <= 20 * 60, "Apple refuse un jeton de plus de vingt minutes");
  assert.ok(
    verify("sha256", Buffer.from(`${header}.${payload}`), { key: publicKey, dsaEncoding: "ieee-p1363" }, Buffer.from(signature, "base64url")),
  );
  assert.ok(readPrivateKey(Buffer.from(pem).toString("base64")));
});

test("une clé individuelle signe « sub: user » au lieu d'un Issuer ID", () => {
  const { privateKey } = generateKeyPairSync("ec", { namedCurve: "P-256" });
  const token = makeToken({ keyId: "KEY", issuerId: "", privateKey, now: 1000 });
  const claims = JSON.parse(Buffer.from(token.split(".")[1], "base64url"));
  assert.equal(claims.sub, "user");
  assert.equal(claims.iss, undefined);
});

test("les secrets mal formés sont signalés avant d'appeler Apple", () => {
  const issuer = "57246542-96fe-1a63-e053-0824d011072a";
  assert.deepEqual(credentialProblems({ keyId: "2X9R4HXF34", issuerId: issuer }), []);
  assert.deepEqual(credentialProblems({ keyId: "2X9R4HXF34", issuerId: "" }), [], "clé individuelle");
  assert.equal(credentialProblems({ keyId: "2X9R4HXF3", issuerId: issuer }).length, 1, "Key ID trop court");
  // Le Team ID à la place de l'Issuer ID : la confusion la plus fréquente.
  const [teamId] = credentialProblems({ keyId: "2X9R4HXF34", issuerId: "A1B2C3D4E5" });
  assert.match(teamId, /Team ID/);
});

test("dans un pays aligné sur un équivalent, l'annuel et le réduit gardent les rapports de la grille", () => {
  // Seul l'hebdomadaire suit l'équivalent Apple ; les suivants s'en déduisent dans le pays.
  const poland = ruleFor(grid, "POL");
  assert.equal(derivationFor(grid, poland, "weekly"), null);
  const yearly = derivationFor(grid, poland, "yearly");
  assert.equal(yearly.from, "weekly");
  assert.ok(Math.abs(yearly.factor - 39.99 / 3.99) < 1e-9);
  const discount = derivationFor(grid, poland, "discount");
  assert.equal(discount.from, "yearly");
  assert.ok(Math.abs(discount.factor - 23.99 / 39.99) < 1e-9);

  // Les pays non nommés suivent la France, les pays « usd » leur propre ligne.
  assert.ok(Math.abs(derivationFor(grid, ruleFor(grid, "GBR"), "yearly").factor - 49.99 / 4.99) < 1e-9);
  assert.ok(Math.abs(derivationFor(grid, ruleFor(grid, "PAK"), "discount").factor - 11.99 / 19.99) < 1e-9);

  // Un pays à prix écrits ne se déduit pas : il prend ses propres montants.
  assert.equal(derivationFor(grid, ruleFor(grid, "TUR"), "yearly"), null);
  assert.equal(derivationFor(grid, ruleFor(grid, "USA"), "discount"), null);

  // Pakistan : 500 PKR la semaine donne ~5 000 l'an et ~3 000 réduit — plus 4 900 / 3 500.
  const pkr = [500, 2900, 3000, 3500, 4900, 5000].map((p) => ({ id: String(p), customerPrice: String(p) }));
  const pkYearly = pickPricePoint(pkr, 500 * derivationFor(grid, ruleFor(grid, "PAK"), "yearly").factor).point;
  const pkDiscount = pickPricePoint(pkr, Number(pkYearly.customerPrice) * derivationFor(grid, ruleFor(grid, "PAK"), "discount").factor).point;
  assert.equal(pkYearly.customerPrice, "5000");
  assert.equal(pkDiscount.customerPrice, "3000");
  assert.equal(Math.round((1 - 3000 / 5000) * 100), 40);
});

test("un abonnement déjà approuvé change de prix à une date, jamais par un second prix initial", () => {
  // Apple : « Initial price cannot be created again after subscription is approved ».
  assert.equal(priceStartDate(true, "2026-09-28"), "2026-09-28");
  assert.equal(priceStartDate(false, "2026-09-28"), null);
  assert.equal(dayAfter("2026-09-30"), "2026-10-01");
  assert.equal(dayAfter("2026-12-31"), "2027-01-01");
});

test("un changement déjà programmé compte comme posé", () => {
  const prices = [
    { startDate: null, pointId: "old" },
    { startDate: "2099-01-01", pointId: "next" },
  ];
  assert.equal(latestPrice(prices).pointId, "next");
  assert.equal(currentPrice(prices, "2026-09-28").pointId, "old");
});

test("la date minimale se lit dans le refus d'Apple", () => {
  const refusal =
    "POST /v1/subscriptionPrices → 409 ENTITY_ERROR.RELATIONSHIP.INVALID: Invalid startDate=2026-09-29, a future date is expected, and must be on or after 2026-09-30";
  assert.equal(earliestDateFrom(refusal), "2026-09-30");
  assert.equal(earliestDateFrom("409 STATE_ERROR: autre chose"), null);
});
