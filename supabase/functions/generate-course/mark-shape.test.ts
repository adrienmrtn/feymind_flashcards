import { assertEquals } from "jsr:@std/assert@1";

import { cleanMarks } from "./mark-shape.ts";

Deno.test("retire le surlignage posé au milieu d'un mot", () => {
  // Relevé tel quel dans une fiche de production : l'ouverture est collée à « de », la
  // fermeture tombe deux cents caractères plus loin, et le rendu en fait une bande rose
  // sur trois phrases.
  const abîmé =
    "Quandela SAS est une entreprise française fondée en 2017, issue de==rose| 35 ans de recherche du CNRS et de l'Université Paris-Saclay. Elle est spécialisée dans l'informatique quantique photonique. L'entreprise cherche à lever== entre 80M€ et 120M€.";
  const propre = cleanMarks(abîmé);

  assertEquals(propre.includes("=="), false);
  assertEquals(propre.includes("rose|"), false);
  assertEquals(
    propre,
    "Quandela SAS est une entreprise française fondée en 2017, issue de 35 ans de recherche du CNRS et de l'Université Paris-Saclay. Elle est spécialisée dans l'informatique quantique photonique. L'entreprise cherche à lever entre 80M€ et 120M€.",
  );
});

Deno.test("garde une marque bien posée, couleur comprise", () => {
  const texte =
    "La **Rubisco** fixe le carbone. ==menthe|Le rendement réel plafonne à 2 % de l'énergie incidente.== Ce rendement est dit *apparent*.";
  assertEquals(cleanMarks(texte), texte);
});

Deno.test("retire un surlignage qui couvre un paragraphe entier", () => {
  const long = "Le plan de financement " + "détaille chaque poste de dépense. ".repeat(9);
  const texte = `==jaune|${long}==`;
  assertEquals(cleanMarks(texte).includes("=="), false);
  assertEquals(cleanMarks(texte).trim(), long.trim());
});

Deno.test("retire un marqueur resté seul", () => {
  assertEquals(cleanMarks("Un **terme laissé ouvert dans la phrase."), "Un terme laissé ouvert dans la phrase.");
  assertEquals(cleanMarks("Un ==jaune|passage laissé ouvert."), "Un passage laissé ouvert.");
});

Deno.test("refuse un gras qui couvre deux phrases, garde un gras d'un terme", () => {
  assertEquals(
    cleanMarks("**La première phrase tient. La seconde aussi.** Et la suite."),
    "La première phrase tient. La seconde aussi. Et la suite.",
  );
  assertEquals(cleanMarks("Les **forces** de l'entreprise."), "Les **forces** de l'entreprise.");
});

Deno.test("ne touche pas à ce qui vit entre deux dollars", () => {
  // `a^*` et `2*3` sont des formules, pas de l'italique : les démonter casserait le rendu.
  const texte = "La puissance vaut $P = R I^2$ et l'exposant $a^*$ reste intact.";
  assertEquals(cleanMarks(texte), texte);
});

Deno.test("garde l'italique au bord d'une apostrophe", () => {
  const texte = "On parle d'*aléa moral*, pas de négligence.";
  assertEquals(cleanMarks(texte), texte);
});

Deno.test("un texte sans marque ressort identique", () => {
  const texte = "Une phrase ordinaire, sans la moindre marque de relecture.";
  assertEquals(cleanMarks(texte), texte);
  assertEquals(cleanMarks(""), "");
});
