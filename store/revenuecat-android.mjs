#!/usr/bin/env node
/**
 * **RevenueCat pour Android** — l'app Google Play, ses deux abonnements, l'entitlement et
 * l'offering, comme pour l'App Store (`store/revenuecat.mjs`).
 *
 *   node store/revenuecat-android.mjs            simulation : lit tout, n'écrit rien
 *   node store/revenuecat-android.mjs --apply    crée ce qui manque
 *
 * Variables : `REVENUECAT_API_KEY` (clé secrète v2, `sk_…`, écriture sur la configuration
 * du projet) et `REVENUECAT_PROJECT_ID` (par défaut `proj415c7a8d`).
 *
 * Ce que le script fait, et rien d'autre :
 * - l'app Google Play `com.micabo.app` existe dans le projet ;
 * - les abonnements `com.micabo.app.pro.weekly:weekly` et `com.micabo.app.pro.yearly:yearly`
 *   (identifiant d'abonnement Play, deux-points, identifiant du base plan) existent chez
 *   RevenueCat, attachés à l'entitlement `pro` ;
 * - l'offering courante porte chacun dans son package (`$rc_weekly`, `$rc_annual`), à côté
 *   des produits App Store, qui ne bougent pas.
 *
 * Il imprime la clé publique Android (`goog_…`) : elle n'est pas secrète, l'app l'embarque.
 * Le compte de service Google (vérification des achats) et les abonnements eux-mêmes dans
 * la Play Console restent à faire à la main : un script n'a pas à manipuler ces accès.
 */

const apply = process.argv.includes("--apply");
const API = "https://api.revenuecat.com/v2";
const key = process.env.REVENUECAT_API_KEY;
const project = process.env.REVENUECAT_PROJECT_ID || "proj415c7a8d";
const PACKAGE_NAME = "com.micabo.app";
const PLANS = [
  { storeId: "com.micabo.app.pro.weekly:weekly", name: "Micabo Pro — semaine (Android)", pkg: "$rc_weekly" },
  { storeId: "com.micabo.app.pro.yearly:yearly", name: "Micabo Pro — année (Android)", pkg: "$rc_annual" },
];

if (!key) {
  console.error("REVENUECAT_API_KEY absente.");
  process.exit(1);
}

async function call(method, path, body) {
  const url = path.startsWith("http") ? path : `${API}${path}`;
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
      await new Promise((done) => setTimeout(done, Number(json?.backoff_ms) || 2000 * attempt));
      continue;
    }
    throw new Error(`${method} ${path} → ${response.status} ${json?.message ?? text}`);
  }
}

async function list(path) {
  const items = [];
  let next = `${path}${path.includes("?") ? "&" : "?"}limit=100`;
  while (next) {
    const page = await call("GET", next.startsWith("/v2") ? next.slice(3) : next);
    items.push(...(page.items ?? []));
    next = page.next_page ?? null;
  }
  return items;
}

async function write(description, method, path, body) {
  console.log(`${apply ? "→" : "(simulation)"} ${description}`);
  return apply ? call(method, path, body) : null;
}

const base = `/projects/${project}`;

// L'app Google Play.
const apps = await list(`${base}/apps`);
let app = apps.find((a) => a.type === "play_store" && a.play_store?.package_name === PACKAGE_NAME);
if (!app) {
  app = await write(`créer l'app Google Play ${PACKAGE_NAME}`, "POST", `${base}/apps`, {
    name: "Micabo (Google Play)",
    type: "play_store",
    play_store: { package_name: PACKAGE_NAME },
  });
}
if (!app) {
  console.log("Simulation : la suite demande l'app créée. Relancer avec --apply.");
  process.exit(0);
}
console.log(`App Google Play : ${app.name} (${app.id})`);

// La clé publique, pour l'app Android.
const keys = await list(`${base}/apps/${app.id}/public_api_keys`);
const publicKey = keys.find((k) => String(k.key ?? "").startsWith("goog_"))?.key ?? keys[0]?.key;
console.log(`CLÉ PUBLIQUE ANDROID : ${publicKey ?? "(aucune)"}`);
if (process.env.GITHUB_STEP_SUMMARY && publicKey) {
  const { appendFileSync } = await import("node:fs");
  appendFileSync(process.env.GITHUB_STEP_SUMMARY, `Clé publique Android RevenueCat : \`${publicKey}\`\n`);
}

// Les produits.
const existing = await list(`${base}/products?app_id=${app.id}`);
const productIds = {};
for (const plan of PLANS) {
  let product = existing.find((p) => p.store_identifier === plan.storeId);
  if (!product) {
    product = await write(`créer le produit ${plan.storeId}`, "POST", `${base}/products`, {
      store_identifier: plan.storeId,
      app_id: app.id,
      type: "subscription",
      display_name: plan.name,
    });
  }
  if (product) productIds[plan.storeId] = product.id;
}

// L'entitlement `pro`.
const entitlements = await list(`${base}/entitlements`);
const pro = entitlements.find((e) => e.lookup_key === "pro");
if (!pro) throw new Error("Entitlement « pro » introuvable.");
const attached = await list(`${base}/entitlements/${pro.id}/products`);
const missing = Object.values(productIds).filter((id) => !attached.some((p) => p.id === id));
if (missing.length) {
  await write(`attacher ${missing.length} produit(s) Android à « pro »`, "POST", `${base}/entitlements/${pro.id}/actions/attach_products`, {
    product_ids: missing,
  });
}

// L'offering courante et ses packages.
const offerings = await list(`${base}/offerings`);
const current = offerings.find((o) => o.is_current) ?? offerings.find((o) => o.lookup_key === "default");
if (!current) throw new Error("Aucune offering courante.");
const packages = await list(`${base}/offerings/${current.id}/packages`);
for (const plan of PLANS) {
  const pkg = packages.find((p) => p.lookup_key === plan.pkg);
  const productId = productIds[plan.storeId];
  if (!pkg || !productId) {
    console.log(`Package ${plan.pkg} absent de ${current.lookup_key} : rien à attacher.`);
    continue;
  }
  const inside = await list(`${base}/packages/${pkg.id}/products`);
  if (inside.some((p) => (p.product?.id ?? p.id) === productId)) continue;
  await write(`mettre ${plan.storeId} dans ${current.lookup_key}/${plan.pkg}`, "POST", `${base}/packages/${pkg.id}/actions/attach_products`, {
    products: [{ product_id: productId, eligibility_criteria: "all" }],
  });
}

console.log(apply ? "RevenueCat Android : prêt." : "Simulation finie.");
