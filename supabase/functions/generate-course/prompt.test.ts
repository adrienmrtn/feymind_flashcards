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
  assertEquals(PROMPT_VERSION, "course-v2.7.0");
});

Deno.test("le prompt d'écriture ne demande plus de mise en relief", () => {
  // Le rédacteur jonglait entre fidélité, plan, longueur ET typographie, et c'est la
  // typographie qu'il ratait une fois sur deux. Elle appartient maintenant à la passe de
  // marquage, qui ne fait que ça et qui vérifie ce qu'elle pose.
  assertEquals(COURSE_SYSTEM_PROMPT.includes("ne compte aucune marque"), true);
  assertEquals(COURSE_SYSTEM_PROMPT.includes("LE CODE COULEUR"), false);
  assertEquals(COURSE_SYSTEM_PROMPT.includes("LA POSE D'UNE MARQUE"), false);
  assertEquals(COURSE_SYSTEM_PROMPT.includes("OÙ POSER LE SURLIGNEUR"), false);

  // Les densités chiffrées vivaient ici et dans `marks.ts`, en deux exemplaires qui
  // pouvaient diverger. Il n'en reste qu'un, et c'est `CHARS_PER`.
  assertEquals(COURSE_SYSTEM_PROMPT.includes("DEUX CENT CINQUANTE CARACTÈRES"), false);
  assertEquals(COURSE_SYSTEM_PROMPT.includes("HUIT CENTS CARACTÈRES"), false);

  // Aucune teinte n'y est plus nommée : c'est la passe de marquage qui les connaît.
  for (const colour of SHEET_HIGHLIGHTS) {
    assertEquals(COURSE_SYSTEM_PROMPT.includes(`${colour}|`), false);
  }
});

Deno.test("le prompt garde ce qui touche à la sortie, et ça seul", () => {
  // Le gras reste : c'est la seule marque que le rédacteur posait de façon fiable, et la
  // consigne lui dit maintenant de la poser sans se fixer de compte.
  assertEquals(COURSE_SYSTEM_PROMPT.includes("**terme** met en gras"), true);
  assertEquals(COURSE_SYSTEM_PROMPT.includes("sans te fixer de compte"), true);

  // Le surlignage et l'italique, non : posés au jugé par le rédacteur, ils seraient comptés
  // comme déjà présents et la passe ne les reposerait pas.
  assertEquals(COURSE_SYSTEM_PROMPT.includes("ni ==surlignage==, ni *italique*"), true);

  // Les formules dans la phrase restent : c'est la sortie elle-même, pas du relief. Une
  // commande LaTeX nue hors de $…$ casse le rendu sur les deux clients.
  assertEquals(COURSE_SYSTEM_PROMPT.includes("LES FORMULES DANS LA PHRASE"), true);
  assertEquals(COURSE_SYSTEM_PROMPT.includes("$E = mc^2$ compose une formule"), true);
  assertEquals(COURSE_SYSTEM_PROMPT.includes("UN PARAGRAPHE CORRECTEMENT ÉCRIT"), true);
  // L'exemple a déteint une fois : le modèle a repris ses italiques mot pour mot sur un
  // document qui parlait d'autre chose. Il dit toujours qu'il ne montre qu'une forme.
  assertEquals(COURSE_SYSTEM_PROMPT.includes("Cet exemple montre une FORME"), true);
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

/**
 * **Le prompt système doit rester assez long pour être mis en cache.**
 *
 * Gemini met en cache, tout seul, un préfixe commun placé en tête de la requête - et le prompt
 * système l'est, des deux côtés, chez fal comme sur l'endpoint compatible. Le préfixe doit
 * atteindre deux mille quarante-huit jetons sur Gemini 2.5. En dessous, il n'est plus mis en
 * cache du tout, et chaque fiche repaie son entrée au tarif plein.
 *
 * Ce n'est pas théorique : en sortant la typographie d'ici, on a retiré 28 % de ce prompt d'un
 * coup. Un second geste de cette ampleur le ferait passer sous le seuil, et la perte ne se
 * verrait nulle part - juste une ligne de facture un peu plus haute.
 *
 * Le plancher est écrit en caractères parce que c'est ce qu'on peut compter ici, et au pire
 * taux : quatre caractères par jeton est ce que le français donne de plus économe, donc le cas
 * où le prompt vaut le moins de jetons.
 *
 * À noter, et c'est la raison pour laquelle `meta.usage.served` existe : les générations 3.x
 * demandent quatre mille quatre-vingt-seize jetons. Ce prompt ne les atteint à aucun taux. Si
 * un alias `-latest` du chemin de repli est monté d'une génération, le cache y est perdu en
 * plus du tarif, et seul le nom du modèle servi le dira.
 */
Deno.test("le prompt système reste au-dessus du seuil de mise en cache", () => {
  const FLOOR = 2_048 * 4;
  assertEquals(
    COURSE_SYSTEM_PROMPT.length >= FLOOR,
    true,
    `${COURSE_SYSTEM_PROMPT.length} caractères, plancher ${FLOOR}`,
  );
});
