/**
 * **Préparer un envoi dans TestFlight sans Xcode Cloud.** Le workflow « TestFlight » archive
 * l'app sur un Mac de GitHub et l'envoie à App Store Connect ; ce script lui donne ce que
 * Xcode Cloud fournissait tout seul :
 *
 * - l'équipe (Team ID), lue sur l'identifiant de l'app (`seedId`) ;
 * - le numéro de build : le plus grand déjà reçu, plus un — Apple refuse un numéro qui
 *   n'est pas au-dessus des précédents ;
 * - la clé d'API en fichier `.p8`, là où `xcodebuild` la cherche pour signer et envoyer.
 *
 *     ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_PRIVATE_KEY=… node store/testflight.mjs
 *
 * Les valeurs partent dans `$GITHUB_OUTPUT` (team, build, key_path, key_id, issuer_id).
 * Côté Apple, une seule écriture : la révocation des certificats de développement laissés par
 * les builds précédents (voir plus bas).
 */

import { appendFileSync, mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { AppStoreConnect, credentialProblems, readPrivateKey } from "./lib/asc.mjs";
import { loadGrid } from "./lib/grid.mjs";

const keyId = (process.env.ASC_KEY_ID ?? "").trim();
const issuerId = (process.env.ASC_ISSUER_ID ?? "").trim();
const privateKey = process.env.ASC_PRIVATE_KEY ?? "";

if (!keyId || !privateKey) {
  console.error("Secrets ASC_KEY_ID et ASC_PRIVATE_KEY absents : impossible de signer ni d'envoyer.");
  process.exit(1);
}
const problems = credentialProblems({ keyId, issuerId });
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

// L'équipe : le préfixe de l'identifiant d'app, qui est le Team ID.
let team = (process.env.TEAM_ID ?? "").trim();
try {
  const ids = await asc.get(`/v1/bundleIds?filter[identifier]=${encodeURIComponent(bundleId)}&limit=5`);
  const exact = (ids.data ?? []).find((item) => item.attributes?.identifier === bundleId);
  team = exact?.attributes?.seedId ?? team;
  console.log(`Identifiant ${bundleId} : équipe ${team || "?"}, plateforme ${exact?.attributes?.platform ?? "?"}`);
} catch (error) {
  console.log(`Identifiants d'app illisibles avec cette clé (${error.message.split("→").pop().trim()}).`);
}
if (!team) {
  console.error("Team ID introuvable : la clé n'a pas accès aux identifiants. Renseigner le secret TEAM_ID.");
  process.exit(1);
}

// **Les certificats de développement des builds précédents.** À chaque archive, xcodebuild
// (`-allowProvisioningUpdates`) crée un certificat de développement dont la clé privée reste
// dans le trousseau du Mac de GitHub, jeté à la fin du run : le certificat ne resservira
// jamais. Ils s'accumulaient jusqu'au plafond d'Apple, et l'archive suivante échouait
// (« Your account has reached the maximum number of certificates »). On les révoque avant
// d'archiver ; ceux de moins d'une heure restent, au cas où un autre run tournerait. Les
// certificats de distribution ne sont jamais touchés.
const DEVELOPMENT = new Set(["DEVELOPMENT", "IOS_DEVELOPMENT"]);
try {
  const certificates = await asc.getAll(`/v1/certificates?limit=200`);
  const byType = new Map();
  for (const item of certificates.data) {
    const type = item.attributes?.certificateType ?? "?";
    byType.set(type, (byType.get(type) ?? 0) + 1);
  }
  console.log(`Certificats visibles : ${[...byType].map(([k, n]) => `${k} ${n}`).join(", ") || "aucun"}`);

  const hourAgo = Date.now() - 60 * 60 * 1000;
  const stale = certificates.data.filter((item) => {
    if (!DEVELOPMENT.has(item.attributes?.certificateType)) return false;
    // L'API ne donne pas la date de création : un certificat de développement vaut un an,
    // la création est donc son expiration moins un an.
    const expires = Date.parse(item.attributes?.expirationDate ?? "");
    if (!Number.isFinite(expires)) return false;
    return expires - 365 * 24 * 60 * 60 * 1000 < hourAgo;
  });
  let revoked = 0;
  for (const item of stale) {
    try {
      await asc.request("DELETE", `/v1/certificates/${item.id}`);
      revoked += 1;
    } catch (error) {
      console.log(`Certificat ${item.id} non révoqué (${error.message.split("→").pop().trim()}).`);
    }
  }
  if (stale.length) console.log(`Certificats de développement des builds précédents révoqués : ${revoked}/${stale.length}.`);
} catch (error) {
  console.log(`Certificats illisibles avec cette clé (${error.message.split("→").pop().trim()}).`);
}

// Le numéro de build : au-dessus de tout ce qu'Apple a déjà reçu pour cette app.
const builds = await asc.getAll(`/v1/builds?filter[app]=${app.id}&limit=200&fields[builds]=version`);
const highest = Math.max(0, ...builds.data.map((item) => Number.parseInt(item.attributes?.version ?? "0", 10) || 0));
const build = highest + 1;
console.log(`Builds déjà reçus : ${builds.data.length}, le plus haut ${highest}. Ce build : ${build}.`);

// La clé, au format attendu par xcodebuild : AuthKey_<ID>.p8, en PEM.
const directory = join(process.env.RUNNER_TEMP ?? process.cwd(), "private_keys");
mkdirSync(directory, { recursive: true });
const keyPath = join(directory, `AuthKey_${keyId}.p8`);
writeFileSync(keyPath, readPrivateKey(privateKey).export({ type: "pkcs8", format: "pem" }), { mode: 0o600 });

const outputs = { team, build, key_path: keyPath, key_id: keyId, issuer_id: issuerId };
if (process.env.GITHUB_OUTPUT) {
  appendFileSync(process.env.GITHUB_OUTPUT, Object.entries(outputs).map(([k, v]) => `${k}=${v}\n`).join(""));
}
console.log(`Prêt : équipe ${team}, build ${build}.`);
