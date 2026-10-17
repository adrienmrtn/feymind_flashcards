#!/usr/bin/env node
/**
 * **Les abonnements Google Play, posés par RevenueCat** : crée un plan d'état du store
 * depuis `store/play-subscriptions.json`, le planifie, vérifie qu'aucun blocage n'est
 * signalé, puis l'applique et attend le résultat. Tout d'une traite : un plan planifié
 * expire en une minute et demie.
 *
 * Variables : `REVENUECAT_API_KEY` (v2, écriture), `REVENUECAT_PROJECT_ID`.
 */
import { readFileSync } from "node:fs";

const key = process.env.REVENUECAT_API_KEY;
const project = process.env.REVENUECAT_PROJECT_ID || "proj415c7a8d";
const base = `https://api.revenuecat.com/v2/projects/${project}/store_state/plans`;
if (!key) throw new Error("REVENUECAT_API_KEY absente.");

async function call(method, url, body) {
  const response = await fetch(url, {
    method,
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  const json = text ? JSON.parse(text) : null;
  if (!response.ok) throw new Error(`${method} ${url} → ${response.status} ${text}`);
  return json;
}

const wait = (ms) => new Promise((done) => setTimeout(done, ms));

async function until(id, statuses) {
  for (let i = 0; i < 60; i += 1) {
    const plan = await call("GET", `${base}/${id}`);
    if (statuses.includes(plan.status)) return plan;
    await wait(2000);
  }
  throw new Error(`Le plan ${id} n'a pas atteint ${statuses.join("/")}.`);
}

// Un seul plan ouvert par app : on écarte ceux qu'un essai précédent a laissés (expirés,
// planifiés, brouillons) avant d'en créer un neuf.
const open = await call("GET", `${base}?limit=50`);
for (const plan of open.items ?? []) {
  if (["applied", "discarded", "cancelled", "apply_errored"].includes(plan.status)) continue;
  const detail = await call("GET", `${base}/${plan.id}`);
  if (!(detail.actions ?? []).includes("discard")) continue;
  await call("POST", `${base}/${plan.id}/actions/discard`, {});
  console.log(`Plan ${plan.id} (${plan.status}) écarté.`);
}

const body = JSON.parse(readFileSync("store/play-subscriptions.json", "utf8"));

// **Ne rien retirer.** Google Play refuse qu'un plan enlève une région qu'un forfait sert
// déjà (il en ajoute parfois de lui-même). On repart donc de l'état actuel du store : ses
// pays, ses prix et ses régions restent, nos valeurs passent par-dessus.
for (const desired of body.desired_states) {
  let current;
  try {
    current = await call("GET", `https://api.revenuecat.com/v2/projects/${project}/products/${desired.product_id}/store_state`);
  } catch (error) {
    console.log(`État actuel illisible pour ${desired.product_id} : ${error.message}`);
    continue;
  }
  const prices = current?.common?.pricing?.territory_prices ?? {};
  const territories = current?.common?.availability?.territories ?? {};
  desired.common.pricing.territory_prices = { ...prices, ...desired.common.pricing.territory_prices };
  desired.common.availability = { territories: { ...territories, ...(desired.common.availability?.territories ?? {}) } };
  for (const [planId, plan] of Object.entries(desired.store_state.base_plans)) {
    const regions = Object.keys(current?.store_state?.base_plans?.[planId]?.regional_configs ?? {});
    for (const offer of Object.values(plan.offers ?? {})) {
      for (const region of regions) {
        offer.regional_configs[region] ??= { new_subscriber_availability: true };
        for (const phase of offer.phases ?? []) phase.regional_configs[region] ??= { free: true };
      }
    }
  }
  console.log(`${desired.product_id} : ${Object.keys(desired.common.pricing.territory_prices).length} pays repris de l'état actuel.`);
}
const created = await call("POST", base, body);
console.log(`Plan créé : ${created.id}`);
await call("POST", `${base}/${created.id}/actions/plan`, {});
const planned = await until(created.id, ["planned", "planned_and_finished", "plan_errored"]);
console.log(`Planifié : ${planned.status} — ${JSON.stringify(planned.summary)}`);
let blocked = false;
for (const item of planned.plan_items ?? []) {
  console.log(`- ${item.store_identifier} : ${item.action}${item.error_message ? ` — ERREUR ${item.error_message}` : ""}`);
  for (const warning of item.warnings ?? []) {
    console.log(`  [${warning.severity}] ${warning.message}`);
    if (warning.severity === "blocker") blocked = true;
  }
  if (item.error_message) blocked = true;
}
if (planned.status === "plan_errored" || blocked) {
  console.log("Blocage : rien n'est appliqué.");
  process.exit(1);
}
if (planned.status === "planned_and_finished" || !planned.has_changes) {
  console.log("Rien à changer : le store est déjà à jour.");
  process.exit(0);
}
await call("POST", `${base}/${created.id}/actions/apply`, {});
const applied = await until(created.id, ["applied", "apply_errored"]);
console.log(`Appliqué : ${applied.status}`);
for (const item of applied.plan_items ?? []) {
  console.log(`- ${item.store_identifier} : ${item.apply_status}${item.apply_error_message ? ` — ${item.apply_error_message}` : ""}`);
}
if (applied.status !== "applied") process.exit(1);
