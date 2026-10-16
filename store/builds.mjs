/**
 * **Où en sont les builds ?** Les derniers builds reçus par TestFlight (traitement, conformité
 * de l'export, test interne) et, si la clé y a accès, les derniers passages Xcode Cloud.
 * Lecture seule : rien n'est lancé ni modifié.
 *
 *     ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_PRIVATE_KEY=… node store/builds.mjs [commit] [date]
 *
 * Avec un commit et sa date, le script dit en dernière ligne si ce commit a donné un build
 * (Xcode Cloud l'a pris, ou un build est arrivé dans TestFlight depuis), et sort en erreur
 * sinon. Le workflow « Prod » le lance avec le commit de tête de `main`.
 *
 * La clé de la grille de prix (rôle App Manager) voit le produit Xcode Cloud mais pas ses
 * passages : Apple répond 404. Le script le dit et s'en tient à TestFlight.
 */

import { AppStoreConnect, credentialProblems } from "./lib/asc.mjs";
import { loadGrid } from "./lib/grid.mjs";

const keyId = process.env.ASC_KEY_ID ?? "";
const issuerId = process.env.ASC_ISSUER_ID ?? "";
const privateKey = process.env.ASC_PRIVATE_KEY ?? "";
const wanted = (process.argv[2] ?? "").trim().toLowerCase();
const since = process.argv[3] ? new Date(process.argv[3]) : null;

if (!keyId || !privateKey) {
  console.error("Secrets ASC_KEY_ID et ASC_PRIVATE_KEY absents : rien à lire.");
  process.exit(1);
}
const problems = credentialProblems({ keyId: keyId.trim(), issuerId: issuerId.trim() });
if (problems.length) {
  console.error(problems.join("\n"));
  process.exit(1);
}

const asc = new AppStoreConnect({ keyId, issuerId, privateKey });
const { bundleId } = loadGrid();

const apps = await asc.get(`/v1/apps?filter[bundleId]=${encodeURIComponent(bundleId)}`);
const app = apps.data?.[0];
if (!app) {
  console.error(`Aucune app ${bundleId} dans App Store Connect.`);
  process.exit(1);
}
console.log(`App : ${app.attributes?.name} (${bundleId})`);

// Apple date à l'heure du Pacifique (`…-07:00`) : tout est ramené en UTC, comme GitHub.
const day = (date) => (date ? `${new Date(date).toISOString().replace("T", " ").slice(0, 16)} UTC` : "—");

// ── TestFlight ──────────────────────────────────────────────────────────────────────────

let arrived = null;
const builds = await asc.get(
  `/v1/builds?filter[app]=${app.id}&sort=-uploadedDate&limit=6&include=preReleaseVersion,buildBetaDetail`,
);
const included = new Map((builds.included ?? []).map((item) => [`${item.type}/${item.id}`, item]));
console.log("\nTestFlight — derniers builds :");
for (const build of builds.data ?? []) {
  const a = build.attributes ?? {};
  const version = included.get(`preReleaseVersions/${build.relationships?.preReleaseVersion?.data?.id}`)?.attributes?.version;
  const beta = included.get(`buildBetaDetails/${build.relationships?.buildBetaDetail?.data?.id}`)?.attributes ?? {};
  const encryption =
    a.usesNonExemptEncryption == null
      ? "conformité export à remplir"
      : a.usesNonExemptEncryption
        ? "chiffrement non exempté"
        : "export : exempté";
  const label = `${version ?? "?"} (${a.version})`;
  if (since && !arrived && a.uploadedDate && new Date(a.uploadedDate) > since) arrived = label;
  console.log(
    `  ${label} · reçu ${day(a.uploadedDate)} · ${a.processingState}` +
      `${a.expired ? ` · expiré (expiration prévue ${day(a.expirationDate)})` : ""} · ${encryption}` +
      `${beta.internalBuildState ? ` · interne : ${beta.internalBuildState}` : ""}`,
  );
}

// ── App Store ───────────────────────────────────────────────────────────────────────────

try {
  const versions = await asc.get(`/v1/apps/${app.id}/appStoreVersions?limit=4`);
  console.log("\nApp Store — dernières versions :");
  for (const version of versions.data ?? []) {
    const a = version.attributes ?? {};
    console.log(`  ${a.versionString} · ${a.appVersionState} / ${a.appStoreState} · créée ${day(a.createdDate)}`);
  }
} catch (error) {
  console.log(`\nApp Store : illisible (${error.message.split("→").pop().trim()}).`);
}

// En vente, et où : une app retirée de la vente (abonnement développeur échu, retrait…) le dit ici.
try {
  const availability = await asc.get(`/v1/apps/${app.id}/appAvailabilityV2`);
  const territories = await asc.getAll(`/v2/appAvailabilities/${availability.data.id}/territoryAvailabilities?limit=200&include=territory`);
  const available = territories.data.filter((t) => t.attributes?.available);
  const statuses = new Map();
  for (const t of territories.data) {
    for (const status of t.attributes?.contentStatuses ?? []) statuses.set(status, (statuses.get(status) ?? 0) + 1);
  }
  const france = territories.data.find((t) => t.relationships?.territory?.data?.id === "FRA");
  console.log(
    `\nApp Store — disponibilité : ${available.length}/${territories.data.length} pays` +
      ` · France : ${france ? `${france.attributes?.available ? "en vente" : "pas en vente"} (${(france.attributes?.contentStatuses ?? []).join(", ")})` : "—"}` +
      ` · statuts : ${[...statuses].map(([k, n]) => `${k} ${n}`).join(", ")}`,
  );
} catch (error) {
  console.log(`\nApp Store — disponibilité : illisible (${error.message.split("→").pop().trim()}).`);
}

// ── Xcode Cloud ─────────────────────────────────────────────────────────────────────────

let seen = null;
try {
  const products = await asc.get(`/v1/ciProducts?limit=200&include=app`);
  const product =
    (products.data ?? []).find((item) => item.relationships?.app?.data?.id === app.id) ??
    ((products.data ?? []).length === 1 ? products.data[0] : null);
  if (!product) throw new Error("aucun produit Xcode Cloud pour cette app");

  const runs = await asc.getAll(`/v1/ciProducts/${product.id}/buildRuns?limit=200`);
  const recent = runs.data
    .slice()
    .sort((a, b) => (b.attributes?.number ?? 0) - (a.attributes?.number ?? 0))
    .slice(0, 8);
  seen = false;
  console.log("\nXcode Cloud — derniers passages :");
  for (const run of recent) {
    const a = run.attributes ?? {};
    const sha = (a.sourceCommit?.commitSha ?? "").slice(0, 7);
    if (wanted && sha && wanted.startsWith(sha)) seen = true;
    console.log(
      `  #${a.number} · ${day(a.createdDate)} · ${sha || "—"} · ${a.executionProgress}` +
        `${a.completionStatus ? ` · ${a.completionStatus}` : ""}` +
        `${a.startReason ? ` · ${a.startReason}` : ""}` +
        `${a.cancelReason ? ` · annulé : ${a.cancelReason}` : ""}`,
    );
  }
} catch (error) {
  console.log(`\nXcode Cloud : illisible avec cette clé (${error.message.split("→").pop().trim()}).`);
}

if (wanted) {
  const short = wanted.slice(0, 7);
  console.log("");
  if (seen) console.log(`Xcode Cloud a pris ${short}.`);
  if (arrived) console.log(`TestFlight a reçu ${arrived} depuis ${short}.`);
  if (!seen && !arrived) {
    console.log(`Pas encore de build pour ${short}${since ? ` (commit du ${day(since.toISOString())})` : ""}.`);
    process.exit(1);
  }
}
