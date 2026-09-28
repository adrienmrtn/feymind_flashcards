#!/usr/bin/env node
/**
 * **Met RevenueCat d'accord avec la grille** — produits, entitlement, offerings.
 *
 *   node store/revenuecat.mjs            simulation : lit tout, n'écrit rien
 *   node store/revenuecat.mjs --apply    crée ce qui manque
 *
 * Variables : `REVENUECAT_API_KEY` (clé secrète **v2**, `sk_…`, droits *Project
 * configuration* en écriture) et `REVENUECAT_PROJECT_ID` (`proj…`).
 *
 * **RevenueCat ne stocke aucun prix** : il lit ceux d'Apple, pays par pays. Ce script ne
 * touche donc qu'à la plomberie qui fait qu'un achat ouvre Pro :
 *
 * - les trois produits App Store existent chez RevenueCat ;
 * - ils sont tous attachés à l'entitlement `pro` ;
 * - l'offering `default` (courant) porte l'annuel et l'hebdomadaire, l'offering `discount`
 *   porte le tarif réduit — c'est là que `PaywallPurchases.buy` les cherche.
 *
 * Il **n'enlève rien** qu'il n'a pas à remplacer : les produits Stripe attachés à `pro`
 * restent attachés, un offering de plus reste là. Seul un package qui porte le mauvais
 * produit App Store est corrigé, parce qu'un package ne peut porter qu'un produit par app.
 */

import { appendFileSync } from "node:fs";
import { loadGrid } from "./lib/grid.mjs";

const apply = process.argv.includes("--apply");
const grid = loadGrid();
const API = "https://api.revenuecat.com/v2";
const key = process.env.REVENUECAT_API_KEY;
const project = process.env.REVENUECAT_PROJECT_ID;

if (!key || !project) {
  console.error("REVENUECAT_API_KEY et REVENUECAT_PROJECT_ID sont nécessaires. Voir docs/revenuecat.md, §15.");
  process.exit(1);
}

const actions = [];
const warnings = [];
const log = (...args) => console.log(...args);

async function call(method, path, body) {
  const url = path.startsWith("http") ? path : `${API}${path.startsWith("/v2") ? path.slice(3) : path}`;
  for (let attempt = 1; ; attempt += 1) {
    const response = await fetch(url, {
      method,
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: body ? JSON.stringify(body) : undefined,
    });
    const text = await response.text();
    const json = text ? JSON.parse(text) : null;
    if (response.ok) return json;
    if (response.status === 429 && attempt < 6) {
      const wait = Number(json?.backoff_ms) || 2000 * attempt;
      await new Promise((done) => setTimeout(done, wait));
      continue;
    }
    throw new Error(`${method} ${path} → ${response.status} ${json?.message ?? text}`);
  }
}

async function list(path) {
  const items = [];
  let next = `${path}${path.includes("?") ? "&" : "?"}limit=100`;
  while (next) {
    const page = await call("GET", next);
    items.push(...(page.items ?? []));
    next = page.next_page ?? null;
  }
  return items;
}

/** Une écriture, ou sa description en simulation. */
async function write(description, method, path, body) {
  actions.push(description);
  log(`${apply ? "→" : "(simulation)"} ${description}`);
  if (!apply) return null;
  return call(method, path, body);
}

const base = `/projects/${project}`;

// ── L'app App Store ─────────────────────────────────────────────────────────────────────

const apps = await list(`${base}/apps`);
const app = apps.find((a) => a.type === "app_store" && a.app_store?.bundle_id === grid.bundleId);
if (!app) {
  console.error(
    `Aucune app App Store ${grid.bundleId} dans le projet RevenueCat.\n` +
      "L'ajouter à la main (docs/revenuecat.md, §4.2) : elle demande la clé In-App Purchase .p8, qu'un script n'a pas à manipuler.",
  );
  process.exit(1);
}
log(`App RevenueCat : ${app.name} (${app.id})`);
if (!app.app_store?.subscription_key_configured) {
  warnings.push("La clé In-App Purchase n'est pas configurée chez RevenueCat : les achats ne seront pas vérifiés côté serveur (§3–4).");
}
if (!app.app_store?.app_store_connect_api_key_configured) {
  warnings.push("La clé App Store Connect API n'est pas configurée chez RevenueCat : l'import de produits et les prix du tableau de bord seront incomplets.");
}

// ── Les produits ────────────────────────────────────────────────────────────────────────

const existing = await list(`${base}/products?app_id=${app.id}`);
const products = {}; // clé de grille → id RevenueCat
for (const [planKey, product] of Object.entries(grid.products)) {
  const found = existing.find((p) => p.store_identifier === product.productId);
  if (found) {
    if (found.state === "inactive") warnings.push(`${product.productId} est archivé chez RevenueCat`);
    products[planKey] = found.id;
    continue;
  }
  const created = await write(`créer le produit ${product.productId}`, "POST", `${base}/products`, {
    store_identifier: product.productId,
    app_id: app.id,
    type: "subscription",
    display_name: product.productId,
  });
  products[planKey] = created?.id ?? `(nouveau ${product.productId})`;
}

// ── L'entitlement ───────────────────────────────────────────────────────────────────────

const wantedEntitlement = grid.revenuecat.entitlement;
const entitlements = await list(`${base}/entitlements`);
let entitlement = entitlements.find((e) => e.lookup_key === wantedEntitlement.lookupKey);
if (!entitlement) {
  entitlement = await write(`créer l'entitlement ${wantedEntitlement.lookupKey}`, "POST", `${base}/entitlements`, {
    lookup_key: wantedEntitlement.lookupKey,
    display_name: wantedEntitlement.displayName,
  });
}
const attached = entitlement?.id ? await list(`${base}/entitlements/${entitlement.id}/products`) : [];
const toAttach = Object.entries(products)
  .filter(([, id]) => !attached.some((p) => p.id === id))
  .map(([planKey, id]) => ({ planKey, id }));
if (toAttach.length) {
  await write(
    `attacher ${toAttach.map((p) => grid.products[p.planKey].productId).join(", ")} à ${wantedEntitlement.lookupKey}`,
    "POST",
    `${base}/entitlements/${entitlement?.id}/actions/attach_products`,
    { product_ids: toAttach.map((p) => p.id) },
  );
}

// ── Les offerings et leurs packages ─────────────────────────────────────────────────────

const offerings = await list(`${base}/offerings`);
for (const wanted of grid.revenuecat.offerings) {
  let offering = offerings.find((o) => o.lookup_key === wanted.lookupKey);
  if (!offering) {
    offering = await write(`créer l'offering ${wanted.lookupKey}`, "POST", `${base}/offerings`, {
      lookup_key: wanted.lookupKey,
      display_name: wanted.displayName,
    });
  } else if (offering.state === "inactive") {
    warnings.push(`L'offering ${wanted.lookupKey} est archivé : le SDK ne le renvoie pas.`);
  }
  if (wanted.current && !offering?.is_current) {
    await write(`faire de ${wanted.lookupKey} l'offering courant`, "POST", `${base}/offerings/${offering?.id}`, {
      is_current: true,
    });
  }

  const packages = offering?.id ? await list(`${base}/offerings/${offering.id}/packages`) : [];
  for (const [index, wantedPackage] of wanted.packages.entries()) {
    const productId = products[wantedPackage.product];
    let pkg = packages.find((p) => p.lookup_key === wantedPackage.lookupKey);
    if (!pkg) {
      pkg = await write(
        `créer le package ${wanted.lookupKey}/${wantedPackage.lookupKey}`,
        "POST",
        `${base}/offerings/${offering?.id}/packages`,
        { lookup_key: wantedPackage.lookupKey, display_name: wantedPackage.displayName, position: index + 1 },
      );
    }
    const inPackage = pkg?.id ? await list(`${base}/packages/${pkg.id}/products`) : [];
    const ours = inPackage.filter((entry) => entry.product?.app_id === app.id);
    if (ours.some((entry) => entry.product.id === productId)) continue;

    const wrong = ours.map((entry) => entry.product);
    if (wrong.length) {
      await write(
        `retirer ${wrong.map((p) => p.store_identifier).join(", ")} de ${wanted.lookupKey}/${wantedPackage.lookupKey}`,
        "POST",
        `${base}/packages/${pkg?.id}/actions/detach_products`,
        { product_ids: wrong.map((p) => p.id) },
      );
    }
    await write(
      `mettre ${grid.products[wantedPackage.product].productId} dans ${wanted.lookupKey}/${wantedPackage.lookupKey}`,
      "POST",
      `${base}/packages/${pkg?.id}/actions/attach_products`,
      { products: [{ product_id: productId, eligibility_criteria: "all" }] },
    );
  }
}

// ── Le compte rendu ─────────────────────────────────────────────────────────────────────

const report = [
  `## RevenueCat — ${apply ? "appliqué" : "simulation"}`,
  "",
  actions.length ? `- ${actions.join("\n- ")}` : "Rien à faire : produits, entitlement et offerings sont déjà en place.",
  warnings.length ? `\n### À vérifier\n\n- ${warnings.join("\n- ")}` : "",
].join("\n");
log("\n" + report);
if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, report + "\n\n");
