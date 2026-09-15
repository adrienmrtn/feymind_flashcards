import { assertEquals } from "jsr:@std/assert@1";

import { clampSummary, SUMMARY_MAX_WORDS } from "./sheet.ts";

/** Compte les mots comme la limite les compte : séparés par des blancs. */
const words = (text: string) => text.split(/\s+/).filter(Boolean).length;

Deno.test("un chapeau qui tient dans la limite n'est pas touché", () => {
  const court = "La photosynthèse convertit l'énergie lumineuse en énergie chimique dans le chloroplaste.";
  assertEquals(clampSummary(court), court);
});

Deno.test("les espaces multiples et les retours à la ligne sont ramenés à un blanc", () => {
  // Le modèle rend parfois un résumé sur deux lignes ; deux lignes dans un chapeau composé
  // en grand poussent la fiche d'un cran de plus sous la ligne de flottaison.
  assertEquals(clampSummary("Deux  phrases.\n Et un retour."), "Deux phrases. Et un retour.");
});

Deno.test("la coupe tombe sur une fin de phrase, pas au milieu", () => {
  // C'est le cas courant : le modèle écrit deux phrases, la première tient, la seconde non.
  const deux =
    "La révolution industrielle transforme l'Angleterre entre 1760 et 1840. " +
    "Elle déplace les campagnes vers les villes et invente le salariat moderne.";

  const clamped = clampSummary(deux);
  assertEquals(clamped, "La révolution industrielle transforme l'Angleterre entre 1760 et 1840.");
  assertEquals(words(clamped) <= SUMMARY_MAX_WORDS, true);
});

Deno.test("une seule phrase trop longue se coupe au mot, avec des points de suspension", () => {
  // Il n'y a pas de bord de phrase où s'arrêter : une coupe nette vaut mieux qu'un chapeau
  // qui déborde, et les points de suspension disent que la phrase a été écourtée.
  const longue =
    "Le droit administratif règle les rapports entre l'administration et les administrés, " +
    "organise le contentieux devant le juge administratif et fixe les conditions de légalité des actes.";

  const clamped = clampSummary(longue);
  assertEquals(clamped.endsWith("…"), true);
  // Les points de suspension ne comptent pas pour un mot : ils sont collés au dernier.
  assertEquals(words(clamped), SUMMARY_MAX_WORDS);
  assertEquals(clamped.includes("  "), false);
});

Deno.test("la coupe au mot ne laisse pas de ponctuation pendante", () => {
  // « …des actes, … » se lit comme une panne d'affichage.
  const virgule = `${"mot ".repeat(SUMMARY_MAX_WORDS - 1)}dernier, suite de la phrase qui déborde`;
  const clamped = clampSummary(virgule);
  assertEquals(clamped.endsWith("dernier…"), true);
});

Deno.test("un chapeau vide reste vide", () => {
  // Le modèle en saute un de temps en temps, et l'écran sait ne rien afficher.
  assertEquals(clampSummary(""), "");
  assertEquals(clampSummary("   \n  "), "");
});

Deno.test("le compte est global, pas par phrase", () => {
  // Quatre phrases courtes dépassent la limite aussi sûrement qu'une longue : on en garde
  // autant qu'il en tient, et la quatrième (quatre mots de plus) ne tient pas.
  const hachée = "Le sol est acide. La plante souffre. Le rendement baisse. Le sol se lessive.";
  const clamped = clampSummary(hachée, 10);

  assertEquals(clamped, "Le sol est acide. La plante souffre. Le rendement baisse.");
  assertEquals(words(clamped), 10);
});

Deno.test("le plafond vaut vingt mots", () => {
  // Recopié dans `SheetLimits.summaryWords` côté app : deux plafonds différents donneraient
  // deux chapeaux différents pour la même fiche selon l'écran ouvert.
  assertEquals(SUMMARY_MAX_WORDS, 20);
});
