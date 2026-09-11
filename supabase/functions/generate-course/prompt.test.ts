import { assertEquals } from "jsr:@std/assert@1";

import { SHEET_HIGHLIGHTS } from "../_shared/sheet.ts";
import {
  audienceBrief,
  COURSE_SYSTEM_PROMPT,
  instructionsBrief,
  lengthBrief,
  PROMPT_VERSION,
  readingBrief,
  retryBrief,
} from "./prompt.ts";

Deno.test("la version de prompt est stable", () => {
  assertEquals(PROMPT_VERSION, "course-v2.3.0");
});

Deno.test("le prompt demande les trois marques de texte", () => {
  // Une fiche en texte nu se relit mal, et c'est le défaut qu'on corrigeait ici : le gras
  // n'apparaissait que dans les titres, l'italique nulle part.
  assertEquals(COURSE_SYSTEM_PROMPT.includes("**terme** met en gras"), true);
  assertEquals(COURSE_SYSTEM_PROMPT.includes("*nuance* met en italique"), true);
  assertEquals(COURSE_SYSTEM_PROMPT.includes("==couleur|passage=="), true);
});

Deno.test("le prompt montre un paragraphe marqué plutôt que de le décrire", () => {
  // Les consignes seules donnaient du gras et rien d'autre : ni italique, ni formule dans la
  // phrase. Un exemple travaillé porte la densité attendue mieux qu'un plancher chiffré.
  assertEquals(COURSE_SYSTEM_PROMPT.includes("UN PARAGRAPHE CORRECTEMENT MARQUÉ"), true);
  assertEquals(COURSE_SYSTEM_PROMPT.includes("LES FORMULES DANS LA PHRASE"), true);
  // L'exemple a déteint une fois : le modèle a repris ses deux italiques mot pour mot sur un
  // document qui parlait d'autre chose. Il dit maintenant qu'il ne montre qu'une forme.
  assertEquals(COURSE_SYSTEM_PROMPT.includes("Cet exemple montre une FORME"), true);
});

Deno.test("le code couleur ne nomme que des surligneurs qui existent", () => {
  // Un nom de couleur inconnu du rendu laisserait « framboise|texte » dans la phrase, sur
  // les deux clients à la fois. Les cinq teintes viennent de `SHEET_HIGHLIGHTS`.
  const named = [...COURSE_SYSTEM_PROMPT.matchAll(/^- ([a-zéèêà]+) : /gmu)].map((match) =>
    match[1]
  );
  assertEquals(named.length > 0, true);
  for (const colour of named) {
    assertEquals(SHEET_HIGHLIGHTS.includes(colour as typeof SHEET_HIGHLIGHTS[number]), true);
  }
  // Et réciproquement : les cinq feutres ont chacun leur ligne, sinon l'un d'eux ne serait
  // jamais posé par le modèle.
  for (const colour of SHEET_HIGHLIGHTS) {
    assertEquals(named.includes(colour), true);
  }
});

Deno.test("audienceBrief mappe lycée + France", () => {
  const brief = audienceBrief("lycee", "fr");
  assertEquals(brief.includes("SECONDAIRE"), true);
  assertEquals(brief.includes("FRANCE"), true);
});

Deno.test("lengthBrief honore un volume explicite", () => {
  const brief = lengthBrief("standard", false, 20);
  assertEquals(brief.includes("Volume visé : 20 blocs"), true);
});

Deno.test("readingBrief prévient sur un document court", () => {
  const brief = readingBrief("photo", 500);
  assertEquals(brief.includes("COURT"), true);
});

Deno.test("retryBrief nomme un volume", () => {
  assertEquals(retryBrief("brief").includes("12 blocs"), true);
});

Deno.test("instructionsBrief est vide sans texte", () => {
  assertEquals(instructionsBrief(""), "");
});

Deno.test("instructionsBrief encadre le prompt de l'étudiant", () => {
  const brief = instructionsBrief("Insiste sur les formules.");
  assertEquals(brief.includes("CONSIGNES PARTICULIÈRES"), true);
  assertEquals(brief.includes("Insiste sur les formules."), true);
  assertEquals(brief.includes("inventer"), true);
});
