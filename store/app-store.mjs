#!/usr/bin/env node
/**
 * **Pose la grille de `store/pricing.json` dans App Store Connect.**
 *
 *   node store/app-store.mjs            simulation : lit tout, n'écrit rien, dit ce qu'il ferait
 *   node store/app-store.mjs --apply    écrit les prix et les essais gratuits
 *
 * Variables : `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY` (le contenu du `.p8`).
 *
 * Ce que le script fait, produit par produit (hebdomadaire, annuel, annuel réduit) :
 *
 * 1. **Les prix, pays par pays.** Un pays avec un prix écrit reçoit le palier Apple qui porte
 *    ce montant, dans sa devise. Un pays « équivalent » reçoit ce qu'Apple calcule depuis le
 *    pays de référence — c'est le même calcul que le bouton d'App Store Connect. Tout pays
 *    non nommé suit l'équivalent de la France. Un pays déjà au bon prix n'est pas touché.
 * 2. **Les trois jours offerts**, sur l'hebdomadaire et l'annuel, dans chaque pays où ils
 *    manquent. Une offre différente déjà posée n'est jamais remplacée : elle est signalée.
 *
 * **Rien n'est écrit si un seul pays nommé ne se résout pas** : une grille à moitié posée est
 * pire que l'ancienne, parce qu'elle ne correspond plus à aucun fichier.
 */

import { appendFileSync } from "node:fs";
import { AppStoreConnect } from "./lib/asc.mjs";
import {
  currentPrice,
  isActiveOffer,
  loadGrid,
  markdownTable,
  namedTerritories,
  pickPricePoint,
  planKeys,
  ruleFor,
  validateGrid,
} from "./lib/grid.mjs";

const apply = process.argv.includes("--apply");
const grid = loadGrid();
const log = (...args) => console.log(...args);

const problems = validateGrid(grid);
if (problems.length) {
  console.error("La grille est incohérente :\n- " + problems.join("\n- "));
  process.exit(1);
}

for (const name of ["ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY"]) {
  if (!process.env[name]) {
    console.error(`${name} manque. Voir docs/revenuecat.md, §15.`);
    process.exit(1);
  }
}

const asc = new AppStoreConnect({
  keyId: process.env.ASC_KEY_ID,
  issuerId: process.env.ASC_ISSUER_ID,
  privateKey: process.env.ASC_PRIVATE_KEY,
  log,
});

/** Un identifiant de palier Apple est du JSON en base64 : `{"s":…,"t":"FRA","p":…}`. */
function territoryOfPoint(point) {
  const related = point.relationships?.territory?.data?.id;
  if (related) return related;
  try {
    return JSON.parse(Buffer.from(point.id, "base64url").toString("utf8")).t ?? null;
  } catch {
    return null;
  }
}

function simplePoint(point) {
  return { id: point.id, customerPrice: point.attributes?.customerPrice, territory: territoryOfPoint(point) };
}

// ── L'app et ses abonnements ────────────────────────────────────────────────────────────

const apps = await asc.get(`/v1/apps?filter[bundleId]=${encodeURIComponent(grid.bundleId)}`);
const app = apps.data?.[0];
if (!app) {
  console.error(`Aucune app ${grid.bundleId} dans App Store Connect.`);
  process.exit(1);
}
log(`App : ${app.attributes?.name} (${app.id})`);

const groups = await asc.getAll(`/v1/apps/${app.id}/subscriptionGroups?limit=200`);
const subscriptions = new Map();
for (const group of groups.data) {
  const subs = await asc.getAll(`/v1/subscriptionGroups/${group.id}/subscriptions?limit=200`);
  for (const sub of subs.data) subscriptions.set(sub.attributes.productId, { ...sub, group });
}

const missing = planKeys(grid).filter((key) => !subscriptions.has(grid.products[key].productId));
if (missing.length) {
  console.error(
    `Produits absents d'App Store Connect : ${missing.map((k) => grid.products[k].productId).join(", ")}.\n` +
      "Les créer d'abord (docs/revenuecat.md, §2) : le script pose des prix, il n'invente pas de produit.",
  );
  process.exit(1);
}

// ── Lectures, mises en cache ────────────────────────────────────────────────────────────

const memo = new Map();
function once(key, compute) {
  if (!memo.has(key)) memo.set(key, compute());
  return memo.get(key);
}

/** Les pays où l'abonnement est en vente, avec leur devise. */
function territoriesOf(sub) {
  return once(`territories/${sub.id}`, async () => {
    let list;
    try {
      const availability = await asc.get(`/v1/subscriptions/${sub.id}/subscriptionAvailability`);
      list = await asc.getAll(`/v1/subscriptionAvailabilities/${availability.data.id}/availableTerritories?limit=200`);
    } catch (error) {
      if (error.status !== 404) throw error;
      log(`  (${sub.attributes.productId} : pas de disponibilité déclarée, on prend tous les pays)`);
      list = await asc.getAll(`/v1/territories?limit=200`);
    }
    return new Map(list.data.map((t) => [t.id, t.attributes?.currency ?? null]));
  });
}

function pricePointsIn(sub, territory) {
  return once(`points/${sub.id}/${territory}`, async () => {
    const { data } = await asc.getAll(
      `/v1/subscriptions/${sub.id}/pricePoints?filter[territory]=${territory}&limit=8000`,
    );
    return data.map(simplePoint);
  });
}

function equalizationsOf(pointId) {
  return once(`equalizations/${pointId}`, async () => {
    const { data } = await asc.getAll(`/v1/subscriptionPricePoints/${pointId}/equalizations?include=territory&limit=8000`);
    return new Map(data.map(simplePoint).map((point) => [point.territory, point]));
  });
}

async function pointForAmount(sub, territory, amount) {
  const picked = pickPricePoint(await pricePointsIn(sub, territory), amount);
  if (picked.error) throw new Error(`${territory} : ${picked.error}`);
  return picked;
}

/** Le palier visé pour un pays, et d'où il vient. */
async function target(key, sub, territory, currencies) {
  const rule = ruleFor(grid, territory);

  if (rule.rule === "price") {
    const currency = currencies.get(territory);
    if (currency && currency !== rule.currency) {
      throw new Error(`${territory} vend en ${currency}, la grille y écrit des ${rule.currency}`);
    }
    const picked = await pointForAmount(sub, territory, rule.prices[key]);
    return { rule, point: picked.point, warning: picked.warning };
  }

  let anchor;
  let warning = null;
  if (rule.rule === "usd") {
    const picked = await pointForAmount(sub, "USA", rule.prices[key]);
    anchor = picked.point;
    warning = picked.warning;
  } else {
    const from = await target(key, sub, rule.from, currencies);
    anchor = from.point;
  }
  if (territory === anchor.territory) return { rule, point: anchor, warning };
  const point = (await equalizationsOf(anchor.id)).get(territory);
  if (!point) throw new Error(`${territory} : Apple ne donne pas d'équivalent depuis ${anchor.territory}`);
  return { rule, point, warning };
}

/** Les prix en vigueur, par pays : `{ pointId, customerPrice }`. */
async function livePrices(sub) {
  const { data, included } = await asc.getAll(
    `/v1/subscriptions/${sub.id}/prices?include=subscriptionPricePoint,territory&limit=200`,
  );
  const byTerritory = new Map();
  for (const price of data) {
    const territory = price.relationships?.territory?.data?.id;
    const pointId = price.relationships?.subscriptionPricePoint?.data?.id;
    if (!territory) continue;
    const entry = {
      startDate: price.attributes?.startDate ?? null,
      planType: price.attributes?.planType ?? null,
      pointId,
      customerPrice: included.get(`subscriptionPricePoints/${pointId}`)?.attributes?.customerPrice ?? null,
    };
    byTerritory.set(territory, [...(byTerritory.get(territory) ?? []), entry]);
  }
  return new Map([...byTerritory].map(([territory, prices]) => [territory, currentPrice(prices)]));
}

// ── Le plan ─────────────────────────────────────────────────────────────────────────────

const errors = [];
const warnings = [];
const plan = []; // { key, sub, territory, currency, tier, from, to, pointId, change }

for (const key of planKeys(grid)) {
  const sub = subscriptions.get(grid.products[key].productId);
  const currencies = await territoriesOf(sub);
  const live = await livePrices(sub);
  log(`\n${grid.products[key].productId} — ${currencies.size} pays`);

  const named = new Set(namedTerritories(grid));
  const absent = [...named].filter((name) => !currencies.has(name));
  if (absent.length) warnings.push(`${key} : pas en vente dans ${absent.join(", ")} — ces lignes de la grille sont ignorées`);

  for (const [territory, currency] of currencies) {
    try {
      const resolved = await target(key, sub, territory, currencies);
      if (resolved.warning) warnings.push(`${key}/${territory} : ${resolved.warning}`);
      const now = live.get(territory);
      plan.push({
        key,
        sub,
        territory,
        currency,
        tier: resolved.rule.tier,
        named: named.has(territory),
        from: now?.customerPrice ?? null,
        to: resolved.point.customerPrice,
        pointId: resolved.point.id,
        change: now?.pointId !== resolved.point.id,
      });
    } catch (error) {
      (named.has(territory) ? errors : warnings).push(`${key} : ${error.message}`);
    }
  }
}

// ── Les essais gratuits ─────────────────────────────────────────────────────────────────

const trials = []; // { key, sub, territory, duration }
for (const key of planKeys(grid)) {
  const product = grid.products[key];
  const sub = subscriptions.get(product.productId);
  const currencies = await territoriesOf(sub);
  const { data } = await asc.getAll(`/v1/subscriptions/${sub.id}/introductoryOffers?include=territory&limit=200`);
  const active = new Map();
  for (const offer of data) {
    const territory = offer.relationships?.territory?.data?.id;
    if (territory && isActiveOffer(offer.attributes ?? {})) active.set(territory, offer.attributes);
  }

  if (!product.trial) {
    if (active.size) warnings.push(`${key} : ${active.size} pays ont une offre d'introduction alors que la grille n'en prévoit pas — laissées telles quelles`);
    continue;
  }
  for (const territory of currencies.keys()) {
    const offer = active.get(territory);
    if (!offer) {
      trials.push({ key, sub, territory, duration: product.trial });
    } else if (offer.offerMode !== "FREE_TRIAL" || offer.duration !== product.trial) {
      warnings.push(`${key}/${territory} : offre existante ${offer.offerMode} ${offer.duration}, laissée telle quelle`);
    }
  }
}

// ── Le compte rendu ─────────────────────────────────────────────────────────────────────

const changes = plan.filter((row) => row.change);
const namedRows = namedTerritories(grid).map((territory) => {
  const cells = planKeys(grid).map((key) => {
    const row = plan.find((r) => r.key === key && r.territory === territory);
    if (!row) return "—";
    return row.change ? `${row.from ?? "∅"} → **${row.to}**` : `${row.to} ✓`;
  });
  const any = plan.find((r) => r.territory === territory);
  return [territory, ruleFor(grid, territory).tier, any?.currency ?? "?", ...cells];
});
const others = new Set(plan.filter((r) => !r.named).map((r) => r.territory));
const otherChanges = changes.filter((r) => !r.named).length;

const report = [
  `## Grille App Store — ${apply ? "appliquée" : "simulation"}`,
  "",
  markdownTable(["Pays", "Palier", "Devise", ...planKeys(grid)], namedRows),
  "",
  `Autres pays (${others.size}) : équivalent Apple du prix français — ${otherChanges} prix à changer.`,
  "",
  `**${changes.length}** prix à changer, **${trials.length}** essais gratuits à poser.`,
  errors.length ? `\n### Erreurs (rien n'est écrit)\n\n- ${errors.join("\n- ")}` : "",
  warnings.length ? `\n### À vérifier\n\n- ${warnings.join("\n- ")}` : "",
].join("\n");

log("\n" + report);
if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, report + "\n\n");

if (errors.length) process.exit(1);
if (!apply) {
  log("\nSimulation : rien n'a été écrit. Relancer avec --apply pour poser la grille.");
  process.exit(0);
}

// ── L'écriture ──────────────────────────────────────────────────────────────────────────

let written = 0;
for (const row of changes) {
  await asc.post("/v1/subscriptionPrices", {
    data: {
      type: "subscriptionPrices",
      // Tout de suite, et sans toucher aux abonnés en place si le prix monte : une hausse
      // n'est jamais imposée par ce script, elle se décide dans App Store Connect.
      attributes: { startDate: null, preserveCurrentPrice: true },
      relationships: {
        subscription: { data: { type: "subscriptions", id: row.sub.id } },
        subscriptionPricePoint: { data: { type: "subscriptionPricePoints", id: row.pointId } },
        territory: { data: { type: "territories", id: row.territory } },
      },
    },
  });
  written += 1;
  if (written % 25 === 0) log(`  ${written}/${changes.length} prix posés`);
}

let offers = 0;
for (const trial of trials) {
  await asc.post("/v1/subscriptionIntroductoryOffers", {
    data: {
      type: "subscriptionIntroductoryOffers",
      attributes: { duration: trial.duration, offerMode: "FREE_TRIAL", numberOfPeriods: 1, startDate: null, endDate: null },
      relationships: {
        subscription: { data: { type: "subscriptions", id: trial.sub.id } },
        territory: { data: { type: "territories", id: trial.territory } },
      },
    },
  });
  offers += 1;
  if (offers % 25 === 0) log(`  ${offers}/${trials.length} essais posés`);
}

const done = `\n**Fait** : ${written} prix posés, ${offers} essais gratuits créés (${asc.requests} appels à l'API).`;
log(done);
if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, done + "\n");
