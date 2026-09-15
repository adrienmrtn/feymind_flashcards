import { assertEquals } from "jsr:@std/assert@1";

import { SHEET_HIGHLIGHTS } from "../_shared/sheet.ts";
import {
  audienceBrief,
  COURSE_SYSTEM_PROMPT,
  instructionsBrief,
  lengthBrief,
  outputTokenLimit,
  PROMPT_VERSION,
  readingBrief,
  retryBrief,
  retryTokenLimit,
  VISION_SYSTEM_PROMPT,
} from "./prompt.ts";

Deno.test("la version de prompt est stable", () => {
  assertEquals(PROMPT_VERSION, "course-v2.6.0");
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
  // La densité se compte en caractères : « par paragraphe » ne veut rien dire quand un
  // paragraphe fait six cents caractères.
  assertEquals(COURSE_SYSTEM_PROMPT.includes("DEUX CENT CINQUANTE CARACTÈRES"), true);
  assertEquals(COURSE_SYSTEM_PROMPT.includes("LA POSE D'UNE MARQUE"), true);
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

// MARK: - La passe visuelle

Deno.test("la passe visuelle ne demande plus de données que personne ne lit", () => {
  // Elle réclamait des lignes « FIGURE page=N x=… y=… », les coordonnées d'un recadrage.
  // Les figures ont quitté la fiche, plus rien ne parsait ces lignes, et le modèle a continué
  // à mesurer des cadres pendant des mois. Un grep de tout le dépôt le confirme : personne.
  assertEquals(VISION_SYSTEM_PROMPT.includes("FIGURE"), false);
  assertEquals(VISION_SYSTEM_PROMPT.includes("x=0.08"), false);

  // Même chose pour la raison donnée aux valeurs chiffrées : il n'y a plus de bloc graphe à
  // reconstruire. Elles vont dans les phrases, et la consigne le dit maintenant.
  assertEquals(VISION_SYSTEM_PROMPT.includes("reconstruire un graphe"), false);
  assertEquals(VISION_SYSTEM_PROMPT.includes("Relève les valeurs chiffrées"), true);
});

// MARK: - Le plafond de sortie

Deno.test("le plafond de sortie couvre la fiche la plus longue", () => {
  // Mesuré : une fiche approfondie de 70 blocs, paragraphes de 600 caractères, fait 36 595
  // caractères de JSON, soit 9 100 à 11 400 jetons selon ce que le tokeniseur fait du
  // français. L'ancien plafond unique de 8 192 tombait au milieu, et la fiche coupée passait
  // pour bonne : 51 blocs rendus sur 70, sans erreur ni second essai.
  assertEquals(outputTokenLimit("deep") >= 12_000, true);
  assertEquals(outputTokenLimit("deep", 70) >= 12_000, true);

  // Sans volume explicite, c'est la borne haute du format qui décide : une fiche écrite au
  // plafond de son format est exactement le cas qu'on coupait.
  assertEquals(outputTokenLimit("standard") > outputTokenLimit("brief"), true);
  assertEquals(outputTokenLimit("deep") > outputTokenLimit("standard"), true);
});

Deno.test("le plafond suit le volume demandé, et reste borné", () => {
  assertEquals(outputTokenLimit("deep", 70) > outputTokenLimit("deep", 20), true);

  // Un curseur poussé au maximum ne doit pas laisser écrire sans fin, et une fiche minuscule
  // garde de quoi finir sa dernière phrase.
  assertEquals(outputTokenLimit("deep", 999) <= 24_576, true);
  assertEquals(outputTokenLimit("brief", 1) >= 4_096, true);

  // Le second essai écrit plus court : son plafond suit, sinon il ne bornerait rien.
  assertEquals(retryTokenLimit("deep") < outputTokenLimit("deep"), true);
});
