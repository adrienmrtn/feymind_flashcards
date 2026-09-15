import { assertEquals } from "jsr:@std/assert@1";

import { normalizeSheet, SHEET_HIGHLIGHTS } from "../_shared/sheet.ts";
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
  assertEquals(PROMPT_VERSION, "course-v2.8.0");
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

// MARK: - Les listes

/**
 * **Le bloc `list` existait, et ne sortait jamais de la génération.**
 *
 * Rien ne le jetait en chemin : `normalizeSheet` l'accepte, les deux clients le rendent. Le
 * prompt portait cinq découragements contre une permission sous condition, et surtout la seule
 * porte ouverte était « quand le document énumère **vraiment** ». Or un cours énumère en
 * prose - « on distingue trois types de… » - et la fiche avait donc l'interdiction d'en faire
 * une liste. L'étudiant les reposait à la main, après coup.
 */
Deno.test("la consigne dit QUAND une liste vaut mieux qu'un paragraphe", () => {
  // Une liste est une forme que la fiche choisit, pas une forme qu'elle hérite du document.
  assertEquals(COURSE_SYSTEM_PROMPT.includes("même si le document l'écrit en phrases"), true);
  assertEquals(COURSE_SYSTEM_PROMPT.includes("Tu n'attends donc pas que le document mette des puces"), true);

  // Des cas nommés, et non une condition à remplir.
  for (const cas of ["une procédure", "une classification", "les conditions qui doivent", "les critères"]) {
    assertEquals(COURSE_SYSTEM_PROMPT.includes(cas), true, cas);
  }
  assertEquals(COURSE_SYSTEM_PROMPT.includes("Trois membres ou plus, c'est une liste"), true);

  // Les deux garde-fous qui valaient la peine restent, l'absolu qui étouffait tout part.
  assertEquals(COURSE_SYSTEM_PROMPT.includes("Jamais deux listes de suite"), true);
  assertEquals(COURSE_SYSTEM_PROMPT.includes("découper une idée unique"), true);
  assertEquals(COURSE_SYSTEM_PROMPT.includes("MAJORITAIRES"), false);
  assertEquals(COURSE_SYSTEM_PROMPT.includes("largement plus nombreux que les listes"), false);
});

Deno.test("la consigne n'interdit plus les puces en interdisant le markdown", () => {
  // « ni #, ni -, ni tableaux en pipes » : le tiret est la puce du markdown, et le modèle
  // lisait l'interdiction du caractère comme l'interdiction de la forme.
  assertEquals(COURSE_SYSTEM_PROMPT.includes("ni #, ni -,"), false);
  assertEquals(COURSE_SYSTEM_PROMPT.includes('une liste est un bloc "list", pas du texte'), true);
});

/**
 * Les exemples du prompt sont du JSON que le modèle recopiera dans sa forme. S'ils ne
 * survivaient pas à `normalizeSheet`, on lui enseignerait une forme que le serveur jette.
 */
Deno.test("les blocs donnés en exemple sont du JSON qui survit à la normalisation", () => {
  const lines = COURSE_SYSTEM_PROMPT.split("\n").filter((line) => line.startsWith('{"type":'));
  // Le paragraphe, la liste, et les cinq blocs du catalogue.
  assertEquals(lines.length >= 3, true, `${lines.length} exemples trouvés`);

  const blocks = normalizeSheet(lines.map((line) => JSON.parse(line)));
  assertEquals(blocks.length, lines.length, "un exemple a été jeté à la normalisation");

  // Deux listes en exemple : celle du catalogue des blocs, et celle de l'exemple travaillé.
  const lists = blocks.filter((block) => block.type === "list");
  assertEquals(lists.length, 2);

  const worked = lists.find((block) =>
    block.type === "list" && block.items.some((item) => item.includes("hélicase"))
  );
  assertEquals(worked?.type === "list" ? worked.items.length : 0, 3);
  // `ordered` à true : l'exemple porte des étapes, et leur ordre compte.
  assertEquals(worked?.type === "list" ? worked.ordered : null, true);
  // Le gras tient dans un point de liste, et c'est le rédacteur qui le pose : la passe de
  // marquage ne descend pas sous cent caractères, donc un point court ne sera jamais marqué.
  assertEquals(worked?.type === "list" ? worked.items[0]!.includes("**hélicase**") : false, true);
});
