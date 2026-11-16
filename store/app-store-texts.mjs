#!/usr/bin/env node
/**
 * **Les textes des fiches App Store : les lire, et poser ceux de `store/app-store-texts.json`.**
 *
 *   node store/app-store-texts.mjs              lecture : chaque fiche, ses textes, ce qui manque
 *   node store/app-store-texts.mjs --apply      écrit les textes du fichier
 *   node store/app-store-texts.mjs --version 1.12
 *
 * Variables : `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY` (les mêmes que les images).
 *
 * Deux endroits chez Apple :
 * - la fiche de l'app (`appInfoLocalizations`) : `name` (30 car.), `subtitle` (30) ;
 * - la fiche de la version (`appStoreVersionLocalizations`) : `description` (4 000),
 *   `keywords` (100, séparés par des virgules), `promotionalText` (170).
 *
 * Le fichier ne nomme que les fiches à écrire, champ par champ : une fiche ou un champ absent
 * n'est jamais touché. La lecture affiche en entier les textes des fiches de référence
 * (fr-FR, en-US) et dit, pour les autres, quels champs sont vides.
 */

import { existsSync, readFileSync, appendFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { AppStoreConnect, credentialProblems } from "./lib/asc.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const apply = args.includes("--apply");
const wantedVersion = args.includes("--version") ? args[args.indexOf("--version") + 1] : process.env.VERSION || "";
const log = (...parts) => console.log(...parts);
const summary = (text) => process.env.GITHUB_STEP_SUMMARY && appendFileSync(process.env.GITHUB_STEP_SUMMARY, text + "\n");

const LIMITS = { name: 30, subtitle: 30, description: 4000, keywords: 100, promotionalText: 170 };
const APP_FIELDS = ["name", "subtitle"];
const VERSION_FIELDS = ["description", "keywords", "promotionalText"];
const REFERENCES = ["fr-FR", "en-US"];
const EDITABLE = new Set([
  "PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED",
  "WAITING_FOR_REVIEW", "INVALID_BINARY", "READY_FOR_REVIEW",
]);

// ── Le fichier ──────────────────────────────────────────────────────────────────────────

const file = resolve(here, "app-store-texts.json");
const wanted = existsSync(file) ? JSON.parse(readFileSync(file, "utf8")) : {};
const fileProblems = [];
for (const [locale, fields] of Object.entries(wanted)) {
  if (locale.startsWith("_")) continue;
  for (const [field, value] of Object.entries(fields)) {
    if (!(field in LIMITS)) fileProblems.push(`${locale} : champ inconnu « ${field} »`);
    else if ([...value].length > LIMITS[field]) fileProblems.push(`${locale} : ${field} fait ${[...value].length} car. (max ${LIMITS[field]})`);
  }
  if (fields.keywords && /,\s/.test(fields.keywords)) fileProblems.push(`${locale} : pas d'espace après les virgules des mots-clés (chaque caractère compte)`);
}
if (fileProblems.length) {
  console.error("store/app-store-texts.json n'est pas prêt, rien n'est envoyé :\n- " + fileProblems.join("\n- "));
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
const asc = new AppStoreConnect({ ...credentials, privateKey: process.env.ASC_PRIVATE_KEY, log });
const { bundleId } = JSON.parse(readFileSync(resolve(here, "pricing.json"), "utf8"));
const app = (await asc.get(`/v1/apps?filter[bundleId]=${encodeURIComponent(bundleId)}`)).data?.[0];
if (!app) {
  console.error(`Aucune app ${bundleId} dans App Store Connect.`);
  process.exit(1);
}

// ── La version et la fiche de l'app modifiables ─────────────────────────────────────────

const stateOf = (item) => item.attributes?.appVersionState ?? item.attributes?.appStoreState ?? item.attributes?.state;
const versions = (await asc.getAll(`/v1/apps/${app.id}/appStoreVersions?filter[platform]=IOS&limit=50`)).data;
const editable = versions.filter((v) => (wantedVersion ? v.attributes?.versionString === wantedVersion : EDITABLE.has(stateOf(v))));
if (editable.length !== 1) {
  console.error(editable.length ? `Plusieurs versions modifiables : préciser --version.` : "Aucune version modifiable (ou introuvable).");
  process.exit(1);
}
const version = editable[0];
const infos = (await asc.getAll(`/v1/apps/${app.id}/appInfos?limit=10`)).data;
// La fiche de l'app en cours de préparation ; à défaut, la seule qui existe.
const info = infos.find((i) => EDITABLE.has(stateOf(i))) ?? (infos.length === 1 ? infos[0] : null);
log(`App : ${app.attributes?.name} · version ${version.attributes?.versionString} (${stateOf(version)}) · fiche ${info ? stateOf(info) : "?"}`);

const versionLocs = new Map(
  (await asc.getAll(`/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=50`)).data.map((l) => [l.attributes.locale, l]),
);
const appLocs = new Map(
  info ? (await asc.getAll(`/v1/appInfos/${info.id}/appInfoLocalizations?limit=50`)).data.map((l) => [l.attributes.locale, l]) : [],
);
const locales = [...new Set([...versionLocs.keys(), ...appLocs.keys()])].sort();

// ── La lecture ──────────────────────────────────────────────────────────────────────────

const valueOf = (locale, field) =>
  (APP_FIELDS.includes(field) ? appLocs.get(locale) : versionLocs.get(locale))?.attributes?.[field] ?? "";

summary(`### Textes App Store — version ${version.attributes?.versionString}${apply ? "" : " (lecture)"}\n`);
summary("| Fiche | " + Object.keys(LIMITS).join(" | ") + " |");
summary("|---|" + Object.keys(LIMITS).map(() => "---").join("|") + "|");
for (const locale of locales) {
  const cells = Object.keys(LIMITS).map((field) => {
    const length = [...valueOf(locale, field)].length;
    return length ? `${length}` : "**vide**";
  });
  summary(`| ${locale} | ${cells.join(" | ")} |`);
}
for (const locale of REFERENCES.filter((l) => locales.includes(l))) {
  log(`\n════ ${locale} ════`);
  for (const field of Object.keys(LIMITS)) log(`── ${field} ──\n${valueOf(locale, field)}`);
}
log("\nChamps vides par fiche :");
for (const locale of locales) {
  const empty = Object.keys(LIMITS).filter((field) => !valueOf(locale, field));
  if (empty.length) log(`  ${locale.padEnd(8)} ${empty.join(", ")}`);
}

// ── L'écriture ──────────────────────────────────────────────────────────────────────────

const changes = [];
for (const [locale, fields] of Object.entries(wanted)) {
  if (locale.startsWith("_")) continue;
  for (const [kind, fieldNames, locs] of [["appInfoLocalizations", APP_FIELDS, appLocs], ["appStoreVersionLocalizations", VERSION_FIELDS, versionLocs]]) {
    const attributes = Object.fromEntries(
      Object.entries(fields).filter(([field, value]) => fieldNames.includes(field) && valueOf(locale, field) !== value),
    );
    if (!Object.keys(attributes).length) continue;
    const loc = locs.get(locale);
    if (!loc) {
      log(`  ! ${locale} : pas de fiche ${kind} dans App Store Connect, ignorée`);
      continue;
    }
    changes.push({ locale, kind, id: loc.id, attributes });
  }
}
log(`\n${changes.length} écriture(s) ${apply ? "" : "prévue(s) "}:`);
for (const change of changes) log(`  ${change.locale.padEnd(8)} ${Object.keys(change.attributes).join(", ")}`);
summary(`\n${changes.length} écriture(s) ${apply ? "faite(s)" : "prévue(s)"} : ${changes.map((c) => `${c.locale} (${Object.keys(c.attributes).join(", ")})`).join(" · ") || "aucune"}`);

if (apply) {
  for (const change of changes) {
    await asc.request("PATCH", `/v1/${change.kind}/${change.id}`, {
      data: { type: change.kind, id: change.id, attributes: change.attributes },
    });
    log(`✓ ${change.locale} ${Object.keys(change.attributes).join(", ")}`);
  }
}
