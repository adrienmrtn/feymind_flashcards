/**
 * **Les images de la fiche App Store : ce qui se décide sans appeler Apple.**
 *
 * Lire les fichiers et les vérifier, dire à quelle langue va une fiche localisée, et
 * calculer ce qu'il faut changer dans App Store Connect pour qu'elle montre ces images-là.
 * `store/screenshots.mjs` fait les appels ; tout ce qui est ici se teste hors ligne.
 */

import { createHash } from "node:crypto";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { repoRoot } from "./grid.mjs";

export const screenshotsDir = resolve(repoRoot, "store", "screenshots");

/** Les langues dont le dépôt a les images. Une fiche App Store en `en-GB` prend celles de `en`. */
export const LANGUAGES = ["fr", "en", "es", "de", "tr"];

/**
 * Les deux tailles qu'on envoie. L'API garde les noms des anciens écrans : le jeu
 * `APP_IPHONE_67` est celui que l'interface appelle 6,9″ (1320 × 2868), et `APP_IPHONE_61`
 * celui du 6,3″ (1206 × 2622). Les autres tailles d'iPhone se déduisent de celles-ci.
 */
export const DISPLAYS = [
  { key: "6.9", label: "6,9″", type: "APP_IPHONE_67", width: 1320, height: 2868 },
  { key: "6.3", label: "6,3″", type: "APP_IPHONE_61", width: 1206, height: 2622 },
];

/** Une fiche App Store en a dix au plus par taille. */
export const MAX_PER_SET = 10;

/** Les états où les images d'une version se changent encore. Une version en ligne est figée. */
export const EDITABLE_STATES = new Set([
  "PREPARE_FOR_SUBMISSION",
  "DEVELOPER_REJECTED",
  "REJECTED",
  "METADATA_REJECTED",
  "INVALID_BINARY",
]);

const PNG_SIGNATURE = "89504e470d0a1a0a";

/**
 * Largeur, hauteur et transparence d'un PNG, lues dans ses blocs. Apple refuse toute image
 * qui porte un canal alpha, même entièrement opaque : on la refuse avant lui.
 */
export function pngInfo(buffer) {
  if (buffer.subarray(0, 8).toString("hex") !== PNG_SIGNATURE || buffer.subarray(12, 16).toString("latin1") !== "IHDR") {
    throw new Error("ce n'est pas un PNG");
  }
  const width = buffer.readUInt32BE(16);
  const height = buffer.readUInt32BE(20);
  const colorType = buffer[25];
  // Types 4 et 6 : gris ou couleur avec alpha. Un bloc tRNS donne de la transparence aux autres.
  let hasAlpha = colorType === 4 || colorType === 6;
  for (let offset = 8; offset + 8 <= buffer.length && !hasAlpha; ) {
    const length = buffer.readUInt32BE(offset);
    const type = buffer.subarray(offset + 4, offset + 8).toString("latin1");
    if (type === "tRNS") hasAlpha = true;
    if (type === "IDAT" || type === "IEND") break;
    offset += 12 + length;
  }
  return { width, height, colorType, hasAlpha };
}

/**
 * Les images d'une taille, langue par langue, dans l'ordre de leurs noms (`01-…`, `02-…`).
 * Rien n'est envoyé si un seul fichier cloche : `problems` le dit.
 */
export function loadPictures(root, display) {
  const pictures = new Map();
  const problems = [];
  for (const lang of LANGUAGES) {
    const folder = join(root, lang);
    if (!existsSync(folder)) {
      problems.push(`${display.label} ${lang} : dossier ${folder} absent`);
      continue;
    }
    const names = readdirSync(folder).filter((name) => name.endsWith(".png")).sort();
    if (names.length === 0 || names.length > MAX_PER_SET) {
      problems.push(`${display.label} ${lang} : ${names.length} images (il en faut de 1 à ${MAX_PER_SET})`);
    }
    const files = names.map((fileName) => {
      const buffer = readFileSync(join(folder, fileName));
      let info;
      try {
        info = pngInfo(buffer);
      } catch (error) {
        problems.push(`${display.label} ${lang}/${fileName} : ${error.message}`);
        info = {};
      }
      if (info.width !== undefined && (info.width !== display.width || info.height !== display.height)) {
        problems.push(`${display.label} ${lang}/${fileName} : ${info.width} × ${info.height}, attendu ${display.width} × ${display.height}`);
      }
      if (info.hasAlpha) problems.push(`${display.label} ${lang}/${fileName} : canal alpha (Apple le refuse)`);
      return {
        lang,
        fileName,
        size: buffer.length,
        checksum: createHash("md5").update(buffer).digest("hex"),
        buffer,
      };
    });
    pictures.set(lang, files);
  }
  const counts = new Set([...pictures.values()].map((files) => files.length));
  if (counts.size > 1) problems.push(`${display.label} : les langues n'ont pas le même nombre d'images`);
  return { pictures, problems };
}

/** `fr-FR`, `fr-CA` → `fr` ; `zh-Hans` → null : pas d'images pour cette langue. */
export function languageOf(locale) {
  const lang = String(locale).split("-")[0].toLowerCase();
  return LANGUAGES.includes(lang) ? lang : null;
}

/** Le jeu montre-t-il déjà ces images, dans cet ordre ? Apple garde le MD5 qu'on lui a donné. */
export function isUpToDate(existing, wanted) {
  return (
    existing.length === wanted.length &&
    existing.every(
      (shot, index) =>
        shot.attributes?.fileName === wanted[index].fileName &&
        shot.attributes?.sourceFileChecksum === wanted[index].checksum,
    )
  );
}

/**
 * **Ce qu'il faut faire pour une fiche localisée.**
 *
 * `sets` : ses jeux d'images tels qu'App Store Connect les rend, chacun avec ses images
 * (`{ id, type, screenshots }`). `picturesByDisplay` : les images du dépôt, par taille.
 *
 * - Pour chacune de nos deux tailles : rien si le jeu est déjà à jour, sinon le créer au
 *   besoin et remplacer ce qu'il contient.
 * - Les autres tailles d'iPhone qui ont encore des images sont vidées : sans ça, un 6,5″
 *   continuerait de montrer les anciennes, au lieu de la réduction des nouvelles.
 */
export function planLocalization(locale, sets, picturesByDisplay) {
  const lang = languageOf(locale);
  if (!lang) return { locale, lang: null, steps: [], obsolete: [] };

  const steps = DISPLAYS.map((display) => {
    const set = sets.find((candidate) => candidate.type === display.type) ?? null;
    const existing = set?.screenshots ?? [];
    const wanted = picturesByDisplay.get(display.key).get(lang);
    const action = !set ? "créer" : isUpToDate(existing, wanted) ? "à jour" : "remplacer";
    return { display, set, existing, wanted, action };
  });

  const ours = new Set(DISPLAYS.map((display) => display.type));
  const obsolete = sets.filter(
    (set) => set.type.startsWith("APP_IPHONE_") && !ours.has(set.type) && set.screenshots.length > 0,
  );
  return { locale, lang, steps, obsolete };
}
