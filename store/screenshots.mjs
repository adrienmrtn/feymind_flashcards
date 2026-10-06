#!/usr/bin/env node
/**
 * **Pose les images de `store/screenshots/` sur la fiche App Store.**
 *
 *   node store/screenshots.mjs --small <dossier>            simulation : lit tout, n'écrit rien
 *   node store/screenshots.mjs --small <dossier> --apply    envoie les images
 *   … --version 1.8                                        une version précise (sinon : la seule modifiable)
 *
 * `--small` : les images du 6,3″, faites par `store/screenshots/generator/resize.py`.
 * Variables : `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`, comme `store/app-store.mjs`.
 *
 * Pour la version modifiable de l'app (celle qu'on prépare ; une version en ligne est figée),
 * et pour chaque fiche localisée dont la langue a des images dans le dépôt :
 *
 * 1. **Le 6,9″ et le 6,3″ reçoivent les sept images**, dans l'ordre des noms de fichiers. Un jeu
 *    qui les montre déjà n'est pas touché : relancer ne refait rien.
 * 2. **Les nouvelles images arrivent avant que les anciennes partent.** Les anciennes ne sont
 *    supprimées qu'une fois les nouvelles traitées par Apple : un envoi raté laisse la fiche
 *    telle qu'elle était, pas à moitié vide.
 * 3. **Les autres tailles d'iPhone sont vidées** (6,5″, 5,5″…) : App Store Connect y met alors
 *    la réduction des nouvelles, au lieu d'y laisser les anciennes.
 *
 * Une fiche dans une langue sans images (`it`, `ja`…) n'est pas touchée, et la simulation la
 * nomme. Les vidéos d'aperçu non plus.
 */

import { appendFileSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { AppStoreConnect, credentialProblems } from "./lib/asc.mjs";
import { markdownTable, repoRoot } from "./lib/grid.mjs";
import {
  DISPLAYS,
  EDITABLE_STATES,
  MAX_PER_SET,
  loadPictures,
  planLocalization,
  screenshotsDir,
} from "./lib/screenshots.mjs";

const args = process.argv.slice(2);
const apply = args.includes("--apply");
const option = (name) => {
  const index = args.indexOf(name);
  return index >= 0 ? args[index + 1] : undefined;
};
const smallDir = option("--small");
const wantedVersion = option("--version")?.trim() || null;
const log = (...parts) => console.log(...parts);

// ── Les fichiers, vérifiés avant tout appel ─────────────────────────────────────────────

if (!smallDir) {
  console.error(
    "--small manque : le dossier des images du 6,3″.\n" +
      "Les faire avec : python3 store/screenshots/generator/resize.py <dossier>",
  );
  process.exit(1);
}
const roots = { "6.9": screenshotsDir, "6.3": resolve(smallDir) };
const picturesByDisplay = new Map();
const fileProblems = [];
for (const display of DISPLAYS) {
  const { pictures, problems } = loadPictures(roots[display.key], display);
  picturesByDisplay.set(display.key, pictures);
  fileProblems.push(...problems);
}
if (fileProblems.length) {
  console.error("Les images ne sont pas prêtes, rien n'est envoyé :\n- " + fileProblems.join("\n- "));
  process.exit(1);
}

// ── La connexion ────────────────────────────────────────────────────────────────────────

for (const name of ["ASC_KEY_ID", "ASC_PRIVATE_KEY"]) {
  if (!process.env[name]?.trim()) {
    console.error(`${name} manque. Voir docs/revenuecat.md, §15.`);
    process.exit(1);
  }
}
const credentials = { keyId: process.env.ASC_KEY_ID.trim(), issuerId: (process.env.ASC_ISSUER_ID ?? "").trim() };
const shapeProblems = credentialProblems(credentials);
if (shapeProblems.length) {
  console.error("Les secrets App Store Connect n'ont pas la bonne forme :\n- " + shapeProblems.join("\n- "));
  process.exit(1);
}
let asc;
try {
  asc = new AppStoreConnect({ ...credentials, privateKey: process.env.ASC_PRIVATE_KEY, log });
} catch (error) {
  console.error(`ASC_PRIVATE_KEY ne se lit pas comme une clé .p8 (${error.message}).`);
  process.exit(1);
}

const { bundleId } = JSON.parse(readFileSync(resolve(repoRoot, "store", "pricing.json"), "utf8"));
let apps;
try {
  apps = await asc.get(`/v1/apps?filter[bundleId]=${encodeURIComponent(bundleId)}`);
} catch (error) {
  if (error.status !== 401) throw error;
  console.error(
    "Apple refuse la clé (401). La simulation du workflow « Grille de prix iOS » détaille où regarder ;\n" +
      "ce sont les mêmes trois secrets.",
  );
  process.exit(1);
}
const app = apps.data?.[0];
if (!app) {
  console.error(`Aucune app ${bundleId} dans App Store Connect.`);
  process.exit(1);
}
log(`App : ${app.attributes?.name} (${app.id})`);

// ── La version à habiller ───────────────────────────────────────────────────────────────

const stateOf = (version) => version.attributes?.appVersionState ?? version.attributes?.appStoreState;
const versions = (await asc.getAll(`/v1/apps/${app.id}/appStoreVersions?filter[platform]=IOS&limit=50`)).data;
let version;
if (wantedVersion) {
  version = versions.find((candidate) => candidate.attributes?.versionString === wantedVersion);
  if (!version) {
    console.error(`Pas de version ${wantedVersion} pour iOS. Versions : ${versions.map((v) => v.attributes?.versionString).join(", ")}`);
    process.exit(1);
  }
  if (!EDITABLE_STATES.has(stateOf(version))) {
    console.error(`La version ${wantedVersion} est ${stateOf(version)} : ses images ne se changent plus.`);
    process.exit(1);
  }
} else {
  const editable = versions.filter((candidate) => EDITABLE_STATES.has(stateOf(candidate)));
  if (editable.length !== 1) {
    console.error(
      editable.length === 0
        ? "Aucune version modifiable. Les images d'une version en ligne sont figées : créer la version suivante dans App Store Connect, puis relancer."
        : `Plusieurs versions modifiables (${editable.map((v) => v.attributes?.versionString).join(", ")}) : préciser --version.`,
    );
    process.exit(1);
  }
  version = editable[0];
}
log(`Version : ${version.attributes?.versionString} (${stateOf(version)})`);

// ── L'état de chaque fiche localisée ────────────────────────────────────────────────────

const localizations = (await asc.getAll(`/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=50`)).data;
const plans = [];
for (const localization of localizations) {
  const sets = [];
  for (const set of (await asc.getAll(`/v1/appStoreVersionLocalizations/${localization.id}/appScreenshotSets?limit=50`)).data) {
    const screenshots = (await asc.getAll(`/v1/appScreenshotSets/${set.id}/appScreenshots?limit=50`)).data;
    sets.push({ id: set.id, type: set.attributes?.screenshotDisplayType, screenshots });
  }
  plans.push({ localization, ...planLocalization(localization.attributes.locale, sets, picturesByDisplay) });
}

const count = (n) => (n === 1 ? "1 image" : `${n} images`);
const rows = [];
for (const plan of plans) {
  if (!plan.lang) {
    rows.push([plan.locale, "—", "—", "pas d'images dans cette langue : rien n'est touché"]);
    continue;
  }
  for (const step of plan.steps) {
    const before = step.existing.length ? count(step.existing.length) : "aucune";
    const what = { "à jour": "déjà à jour", créer: `créer le jeu, ${count(step.wanted.length)}`, remplacer: `remplacer par ${count(step.wanted.length)}` };
    rows.push([plan.locale, step.display.label, before, what[step.action]]);
  }
  for (const set of plan.obsolete) {
    rows.push([plan.locale, set.type, count(set.screenshots.length), "vider : la réduction du 6,9″ prendra sa place"]);
  }
}
const missingLanguages = [...picturesByDisplay.get("6.9").keys()].filter((lang) => !plans.some((plan) => plan.lang === lang));
const report = [
  `### Images App Store — version ${version.attributes?.versionString}${apply ? "" : " (simulation)"}`,
  "",
  markdownTable(["Fiche", "Taille", "Aujourd'hui", "Ce qui change"], rows),
  ...(missingLanguages.length
    ? ["", `Langues avec des images mais sans fiche dans App Store Connect : ${missingLanguages.join(", ")}. Les ajouter dans App Store Connect pour qu'elles soient servies.`]
    : []),
].join("\n");
log("\n" + report + "\n");
if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, report + "\n\n");

const work = plans.filter((plan) => plan.lang && (plan.steps.some((step) => step.action !== "à jour") || plan.obsolete.length));
if (!work.length || !apply) {
  log(!work.length ? "Tout est déjà à jour." : "Simulation : rien n'est écrit. Relancer avec --apply pour envoyer.");
  process.exit(0);
}

// ── L'envoi ─────────────────────────────────────────────────────────────────────────────

const pause = (ms) => new Promise((done) => setTimeout(done, ms));

/** Réserver la place, déposer le fichier par morceaux comme Apple l'indique, puis le déclarer envoyé. */
async function upload(setId, picture) {
  const reserved = await asc.post("/v1/appScreenshots", {
    data: {
      type: "appScreenshots",
      attributes: { fileName: picture.fileName, fileSize: picture.size },
      relationships: { appScreenshotSet: { data: { type: "appScreenshotSets", id: setId } } },
    },
  });
  const shot = reserved.data;
  try {
    for (const operation of shot.attributes.uploadOperations ?? []) {
      const headers = Object.fromEntries((operation.requestHeaders ?? []).map((header) => [header.name, header.value]));
      const part = picture.buffer.subarray(operation.offset, operation.offset + operation.length);
      for (let attempt = 1; ; attempt += 1) {
        const response = await fetch(operation.url, { method: operation.method, headers, body: part });
        if (response.ok) break;
        if (attempt >= 4 || (response.status < 500 && response.status !== 429)) {
          throw new Error(`dépôt de ${picture.fileName} → ${response.status} ${await response.text()}`);
        }
        await pause(2 ** attempt * 1000);
      }
    }
    await asc.request("PATCH", `/v1/appScreenshots/${shot.id}`, {
      data: { type: "appScreenshots", id: shot.id, attributes: { uploaded: true, sourceFileChecksum: picture.checksum } },
    });
  } catch (error) {
    // Une place réservée et jamais remplie resterait dans le jeu comme une image cassée.
    await asc.request("DELETE", `/v1/appScreenshots/${shot.id}`).catch(() => {});
    throw error;
  }
  return shot.id;
}

/** Apple traite chaque image (dimensions, format) après l'envoi. On attend son verdict. */
async function waitProcessed(ids) {
  const failures = [];
  let pending = [...ids];
  for (const deadline = Date.now() + 10 * 60 * 1000; pending.length && Date.now() < deadline; ) {
    await pause(3000);
    const still = [];
    for (const id of pending) {
      const { data } = await asc.get(`/v1/appScreenshots/${id}?fields[appScreenshots]=fileName,assetDeliveryState`);
      const state = data.attributes?.assetDeliveryState;
      if (state?.state === "COMPLETE") continue;
      if (state?.state === "FAILED") {
        const why = (state.errors ?? []).map((error) => `${error.code}: ${error.description}`).join(" ; ");
        failures.push(`${data.attributes?.fileName} : ${why || "refusée"}`);
        continue;
      }
      still.push(id);
    }
    pending = still;
  }
  if (pending.length) failures.push(`${pending.length} images toujours en traitement au bout de 10 minutes`);
  return failures;
}

async function replace(localization, step) {
  let setId = step.set?.id;
  if (!setId) {
    const created = await asc.post("/v1/appScreenshotSets", {
      data: {
        type: "appScreenshotSets",
        attributes: { screenshotDisplayType: step.display.type },
        relationships: { appStoreVersionLocalization: { data: { type: "appStoreVersionLocalizations", id: localization.id } } },
      },
    });
    setId = created.data.id;
  }

  let old = step.existing.map((shot) => shot.id);
  // Dix images au plus par jeu : s'il n'y a pas la place d'ajouter avant de retirer, on retire d'abord.
  if (old.length + step.wanted.length > MAX_PER_SET) {
    for (const id of old) await asc.request("DELETE", `/v1/appScreenshots/${id}`);
    old = [];
  }

  const fresh = [];
  try {
    for (const picture of step.wanted) fresh.push(await upload(setId, picture));
    const failures = await waitProcessed(fresh);
    if (failures.length) throw new Error(failures.join(" ; "));
  } catch (error) {
    // Les nouvelles repartent toutes ; les anciennes, si elles sont encore là, restent en place.
    for (const id of fresh) await asc.request("DELETE", `/v1/appScreenshots/${id}`).catch(() => {});
    throw error;
  }

  for (const id of old) await asc.request("DELETE", `/v1/appScreenshots/${id}`);
  await asc.request("PATCH", `/v1/appScreenshotSets/${setId}/relationships/appScreenshots`, {
    data: fresh.map((id) => ({ type: "appScreenshots", id })),
  });
}

const errors = [];
for (const plan of work) {
  for (const step of plan.steps.filter((candidate) => candidate.action !== "à jour")) {
    try {
      await replace(plan.localization, step);
      log(`✓ ${plan.locale} ${step.display.label} : ${count(step.wanted.length)}`);
    } catch (error) {
      errors.push(`${plan.locale} ${step.display.label} : ${error.message}`);
      log(`✗ ${plan.locale} ${step.display.label} : ${error.message}`);
    }
  }
  // Une taille n'est vidée que si les nôtres sont bien en place : sinon la fiche resterait sans image.
  if (errors.some((error) => error.startsWith(`${plan.locale} `))) continue;
  for (const set of plan.obsolete) {
    try {
      await asc.request("DELETE", `/v1/appScreenshotSets/${set.id}`);
      log(`✓ ${plan.locale} ${set.type} : vidé`);
    } catch (error) {
      errors.push(`${plan.locale} ${set.type} : ${error.message}`);
    }
  }
}

const done = errors.length
  ? `**${errors.length} envoi(s) en échec** (${asc.requests} appels) :\n- ${errors.join("\n- ")}`
  : `**Images posées** sur ${work.length} fiche(s) (${asc.requests} appels).`;
log("\n" + done);
if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, done + "\n");
process.exit(errors.length ? 1 : 0);
