#!/usr/bin/env node
/**
 * **Le build arrive tout seul chez les testeurs.** Ajoute le dernier build traité par Apple à
 * chaque groupe de test interne de l'app (« xyz » aujourd'hui) : sans ça, il fallait l'ajouter
 * à la main dans App Store Connect, build après build, et un build oublié ne s'installait chez
 * personne.
 *
 *     ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_PRIVATE_KEY=… node store/distribute.mjs
 *
 * Un groupe qui a déjà ce build, ou qui reçoit tous les builds d'office, n'est pas touché. Un
 * refus d'Apple est dit, sans faire échouer l'envoi : le build est là, il reste ajoutable à
 * la main.
 */

import { AppStoreConnect, credentialProblems } from "./lib/asc.mjs";
import { loadGrid } from "./lib/grid.mjs";

const keyId = process.env.ASC_KEY_ID ?? "";
const issuerId = process.env.ASC_ISSUER_ID ?? "";
const privateKey = process.env.ASC_PRIVATE_KEY ?? "";
if (!keyId || !privateKey || credentialProblems({ keyId: keyId.trim(), issuerId: issuerId.trim() }).length) {
  console.log("Clé App Store Connect absente ou incomplète : rien à distribuer.");
  process.exit(0);
}

const asc = new AppStoreConnect({ keyId, issuerId, privateKey });
const { bundleId } = loadGrid();

try {
  const apps = await asc.get(`/v1/apps?filter[bundleId]=${encodeURIComponent(bundleId)}`);
  const app = apps.data?.[0];
  if (!app) throw new Error(`aucune app ${bundleId}`);

  const builds = await asc.get(`/v1/builds?filter[app]=${app.id}&filter[processingState]=VALID&sort=-uploadedDate&limit=1`);
  const build = builds.data?.[0];
  if (!build) throw new Error("aucun build traité");
  const name = `build ${build.attributes?.version}`;

  const groups = await asc.get(`/v1/apps/${app.id}/betaGroups?limit=50`);
  const internal = (groups.data ?? []).filter((group) => group.attributes?.isInternalGroup);
  if (!internal.length) console.log("Aucun groupe de test interne.");

  for (const group of internal) {
    const label = group.attributes?.name ?? group.id;
    if (group.attributes?.hasAccessToAllBuilds) {
      console.log(`« ${label} » reçoit déjà tous les builds.`);
      continue;
    }
    try {
      await asc.post(`/v1/betaGroups/${group.id}/relationships/builds`, { data: [{ type: "builds", id: build.id }] });
      console.log(`${name} ajouté au groupe « ${label} ».`);
    } catch (error) {
      console.log(`::warning::${name} non ajouté à « ${label} » : ${error.message}`);
    }
  }
} catch (error) {
  console.log(`::warning::Distribution impossible : ${error.message}. Ajoute le build au groupe à la main.`);
}
