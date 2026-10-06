/**
 * Les images de la fiche App Store se vérifient sans réseau : `node --test store/`.
 *
 * On fige ici ce qu'Apple refuserait après coup — une mauvaise taille, un canal alpha, une
 * langue à qui il manque une image — et ce que l'envoi décide de toucher ou de laisser.
 */

import assert from "node:assert/strict";
import { test } from "node:test";
import {
  DISPLAYS,
  LANGUAGES,
  isUpToDate,
  languageOf,
  loadPictures,
  planLocalization,
  pngInfo,
  screenshotsDir,
} from "./lib/screenshots.mjs";

/** Un PNG réduit à ses en-têtes : de quoi tester la lecture sans fichier. */
function fakePng({ width = 10, height = 20, colorType = 2, chunks = [] }) {
  const chunk = (type, data) => {
    const length = Buffer.alloc(4);
    length.writeUInt32BE(data.length);
    return Buffer.concat([length, Buffer.from(type, "latin1"), data, Buffer.alloc(4)]);
  };
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header[8] = 8;
  header[9] = colorType;
  return Buffer.concat([
    Buffer.from("89504e470d0a1a0a", "hex"),
    chunk("IHDR", header),
    ...chunks.map(([type, data]) => chunk(type, data)),
    chunk("IDAT", Buffer.alloc(2)),
    chunk("IEND", Buffer.alloc(0)),
  ]);
}

test("les images du dépôt sont prêtes pour le 6,9″ : taille, pas d'alpha, sept par langue", () => {
  const sixNine = DISPLAYS.find((display) => display.key === "6.9");
  const { pictures, problems } = loadPictures(screenshotsDir, sixNine);
  assert.deepEqual(problems, []);
  assert.deepEqual([...pictures.keys()], LANGUAGES);
  for (const lang of LANGUAGES) {
    assert.deepEqual(
      pictures.get(lang).map((picture) => picture.fileName),
      ["01-fiches.png", "02-chiffres.png", "03-reviser.png", "04-quiz.png", "05-mika.png", "06-formules.png", "07-paquets.png"],
    );
  }
});

test("le 6,3″ a les proportions du 6,9″ : une réduction suffit", () => {
  const [large, medium] = DISPLAYS;
  assert.ok(Math.abs(large.width / large.height - medium.width / medium.height) < 0.001);
});

test("la transparence est repérée, qu'elle vienne du type de couleur ou d'un bloc tRNS", () => {
  assert.deepEqual(pngInfo(fakePng({ width: 1320, height: 2868 })), { width: 1320, height: 2868, colorType: 2, hasAlpha: false });
  assert.equal(pngInfo(fakePng({ colorType: 6 })).hasAlpha, true);
  assert.equal(pngInfo(fakePng({ colorType: 4 })).hasAlpha, true);
  assert.equal(pngInfo(fakePng({ colorType: 2, chunks: [["tRNS", Buffer.alloc(6)]] })).hasAlpha, true);
  assert.throws(() => pngInfo(Buffer.from("GIF89a and more bytes here")), /pas un PNG/);
});

test("une fiche prend les images de sa langue, quelle que soit sa région", () => {
  assert.equal(languageOf("fr-FR"), "fr");
  assert.equal(languageOf("fr-CA"), "fr");
  assert.equal(languageOf("en-GB"), "en");
  assert.equal(languageOf("es-MX"), "es");
  assert.equal(languageOf("tr"), "tr");
  assert.equal(languageOf("zh-Hans"), null);
  assert.equal(languageOf("pt-BR"), null);
});

const picture = (fileName, checksum) => ({ fileName, checksum });
const shot = (id, fileName, sourceFileChecksum) => ({ id, attributes: { fileName, sourceFileChecksum } });
const wanted = {
  "6.9": [picture("01-fiches.png", "a1"), picture("02-chiffres.png", "a2")],
  "6.3": [picture("01-fiches.png", "b1"), picture("02-chiffres.png", "b2")],
};
const byDisplay = new Map(
  Object.entries(wanted).map(([key, pictures]) => [key, new Map(LANGUAGES.map((lang) => [lang, pictures]))]),
);

test("un jeu déjà à jour n'est pas touché ; un jeu absent est créé", () => {
  const sets = [{ id: "s67", type: "APP_IPHONE_67", screenshots: [shot("x1", "01-fiches.png", "a1"), shot("x2", "02-chiffres.png", "a2")] }];
  const plan = planLocalization("de-DE", sets, byDisplay);
  assert.equal(plan.lang, "de");
  assert.deepEqual(plan.steps.map((step) => [step.display.type, step.action]), [["APP_IPHONE_67", "à jour"], ["APP_IPHONE_61", "créer"]]);
});

test("les mêmes images dans un autre ordre, ou modifiées, sont remplacées", () => {
  const swapped = [shot("x2", "02-chiffres.png", "a2"), shot("x1", "01-fiches.png", "a1")];
  assert.equal(isUpToDate(swapped, wanted["6.9"]), false);
  const edited = [shot("x1", "01-fiches.png", "a1"), shot("x2", "02-chiffres.png", "changé")];
  assert.equal(isUpToDate(edited, wanted["6.9"]), false);
  const plan = planLocalization("fr-FR", [{ id: "s67", type: "APP_IPHONE_67", screenshots: swapped }], byDisplay);
  assert.equal(plan.steps[0].action, "remplacer");
});

test("les autres tailles d'iPhone qui ont des images sont vidées ; l'iPad et les jeux vides restent", () => {
  const sets = [
    { id: "s65", type: "APP_IPHONE_65", screenshots: [shot("o1", "old.png", "z")] },
    { id: "s55", type: "APP_IPHONE_55", screenshots: [] },
    { id: "ipad", type: "APP_IPAD_PRO_3GEN_129", screenshots: [shot("o2", "ipad.png", "y")] },
  ];
  const plan = planLocalization("en-US", sets, byDisplay);
  assert.deepEqual(plan.obsolete.map((set) => set.id), ["s65"]);
});

test("une fiche dans une langue sans images n'est pas touchée", () => {
  const plan = planLocalization("it", [{ id: "s65", type: "APP_IPHONE_65", screenshots: [shot("o1", "old.png", "z")] }], byDisplay);
  assert.equal(plan.lang, null);
  assert.deepEqual(plan.steps, []);
  assert.deepEqual(plan.obsolete, []);
});
