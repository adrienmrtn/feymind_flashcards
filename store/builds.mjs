/**
 * **Où en sont les builds ?** Les derniers passages Xcode Cloud (quel commit, quel workflow,
 * fini ou non, et pourquoi pas) et les derniers builds reçus par TestFlight (traitement,
 * conformité de l'export, test interne). Lecture seule : rien n'est lancé ni modifié.
 *
 *     ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_PRIVATE_KEY=… node store/builds.mjs [commit]
 *
 * Avec un commit, le script dit en dernière ligne si Xcode Cloud l'a pris, et sort en erreur
 * sinon. Le workflow « Prod » le lance avec le commit de tête de `main`.
 */

import { AppStoreConnect, credentialProblems } from "./lib/asc.mjs";
import { loadGrid } from "./lib/grid.mjs";

const keyId = process.env.ASC_KEY_ID ?? "";
const issuerId = process.env.ASC_ISSUER_ID ?? "";
const privateKey = process.env.ASC_PRIVATE_KEY ?? "";
const wanted = (process.argv[2] ?? "").trim().toLowerCase();

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

// ── Xcode Cloud ─────────────────────────────────────────────────────────────────────────

let seen = false;
let product = null;
for (const path of [`/v1/apps/${app.id}/ciProduct`, `/v1/ciProducts?filter[app]=${app.id}`, `/v1/ciProducts?limit=200&include=app`]) {
  try {
    const products = await asc.get(path);
    const found = [products.data ?? []].flat();
    product = found.find((item) => item.relationships?.app?.data?.id === app.id) ?? (found.length === 1 ? found[0] : null);
    console.log(`\nXcode Cloud : ${path} → ${found.length} produit(s)${found.length ? ` (${found.map((f) => f.attributes?.name).join(", ")})` : ""}`);
    if (product) break;
  } catch (error) {
    console.log(`\nXcode Cloud : ${path} illisible (${error.message})`);
  }
}

if (product) {
  const workflows = await asc.getAll(`/v1/ciProducts/${product.id}/workflows?limit=200`);
  console.log("\nXcode Cloud — workflows :");
  for (const workflow of workflows.data) {
    const a = workflow.attributes ?? {};
    const start = a.branchStartCondition?.source;
    console.log(
      `  ${a.name} · ${a.isEnabled ? "actif" : "DÉSACTIVÉ"}${a.isLockedForEditing ? " · verrouillé" : ""}` +
        (start ? ` · démarre sur ${JSON.stringify(start)}` : ""),
    );
  }

  const runs = await asc.getAll(`/v1/ciProducts/${product.id}/buildRuns?limit=200`);
  const recent = runs.data
    .slice()
    .sort((a, b) => (b.attributes?.number ?? 0) - (a.attributes?.number ?? 0))
    .slice(0, 8);
  console.log("\nXcode Cloud — derniers passages :");
  for (const run of recent) {
    const a = run.attributes ?? {};
    const sha = (a.sourceCommit?.commitSha ?? "").slice(0, 7);
    if (wanted && sha && wanted.startsWith(sha)) seen = true;
    const issues = a.issueCounts ? Object.entries(a.issueCounts).filter(([, n]) => n).map(([k, n]) => `${k} ${n}`).join(", ") : "";
    console.log(
      `  #${a.number} · ${day(a.createdDate)} · ${sha || "—"} · ${a.executionProgress}` +
        `${a.completionStatus ? ` · ${a.completionStatus}` : ""}` +
        `${a.startReason ? ` · ${a.startReason}` : ""}` +
        `${a.cancelReason ? ` · annulé : ${a.cancelReason}` : ""}` +
        `${issues ? ` · ${issues}` : ""}` +
        ` · ${(a.sourceCommit?.message ?? "").split("\n")[0].slice(0, 50)}`,
    );
  }
}

// ── TestFlight ──────────────────────────────────────────────────────────────────────────

const builds = await asc.get(
  `/v1/builds?filter[app]=${app.id}&sort=-uploadedDate&limit=6&include=preReleaseVersion,buildBetaDetail`,
);
const included = new Map((builds.included ?? []).map((item) => [`${item.type}/${item.id}`, item]));
console.log("\nTestFlight — derniers builds :");
for (const build of builds.data ?? []) {
  const a = build.attributes ?? {};
  const version = included.get(`preReleaseVersions/${build.relationships?.preReleaseVersion?.data?.id}`)?.attributes?.version;
  const beta = included.get(`buildBetaDetails/${build.relationships?.buildBetaDetail?.data?.id}`)?.attributes ?? {};
  const encryption = a.usesNonExemptEncryption == null ? "conformité export à remplir" : a.usesNonExemptEncryption ? "chiffrement non exempté" : "export : exempté";
  console.log(
    `  ${version ?? "?"} (${a.version}) · reçu ${day(a.uploadedDate)} · ${a.processingState}` +
      `${a.expired ? " · expiré" : ""} · ${encryption}` +
      `${beta.internalBuildState ? ` · interne : ${beta.internalBuildState}` : ""}`,
  );
}

if (wanted) {
  console.log(
    seen
      ? `\nXcode Cloud a pris ${wanted.slice(0, 7)}.`
      : `\nXcode Cloud n'a pas (encore) pris ${wanted.slice(0, 7)}.`,
  );
  if (!seen) process.exit(1);
}
