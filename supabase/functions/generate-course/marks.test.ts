import { assertEquals } from "jsr:@std/assert@1";

import type { SheetBlock } from "../_shared/sheet.ts";
import {
  batched,
  cleanBlockMarks,
  countMarks,
  MARK_SYSTEM_PROMPT,
  markPrompt,
  markTargets,
  mergeMarked,
  needsMarkPass,
  textsToMark,
} from "./marks.ts";

const PARAGRAPH = (text: string): SheetBlock => ({ type: "paragraph", text });

Deno.test("countMarks ne prend pas le gras pour de l'italique", () => {
  const marks = countMarks([
    PARAGRAPH("La **phase photochimique** produit l'ATP, et le rendement reste *apparent*."),
  ]);
  assertEquals(marks.bold, 1);
  assertEquals(marks.italic, 1);
  assertEquals(marks.highlight, 0);
});

Deno.test("countMarks compte les surlignages et les formules", () => {
  const marks = countMarks([
    PARAGRAPH("==menthe|Le rendement vaut $1$ à $2$ %== sur une feuille bien exposée."),
    { type: "list", ordered: false, items: ["==jaune|Un point marqué==", "Un point nu"] },
  ]);
  assertEquals(marks.highlight, 2);
  assertEquals(marks.math, 2);
});

Deno.test("la seconde passe se déclenche sur la densité, pas sur le zéro", () => {
  // Un paragraphe court et bien marqué : rien à redemander.
  const marked = [
    PARAGRAPH("La **Rubisco** fixe le carbone, ==jaune|et c'est l'étape limitante== du cycle."),
    PARAGRAPH("Le terme *stroma* désigne le compartiment, pas la membrane du thylakoïde."),
  ];
  assertEquals(needsMarkPass(marked), false);

  // Le cas qui échappait au contrôle d'avant : un pavé de six cents caractères portant un
  // seul terme en gras. Zéro nulle part, et pourtant une page sans relief.
  const pavé = PARAGRAPH(
    "Les **forces** de l'entreprise tiennent à ses fondateurs, à sa technologie brevetée et à une licence exclusive. " +
      "Le plan de financement détaille chaque poste de dépense sur trois ans. ".repeat(7),
  );
  assertEquals(needsMarkPass([pavé]), true);
  assertEquals(needsMarkPass([]), false);
});

Deno.test("les cibles suivent la longueur des textes", () => {
  const court = markTargets(["Une phrase de cinquante caractères environ, pas plus."]);
  assertEquals(court.bold, 1);
  // Jamais zéro : même un texte minuscule mérite un repère.
  assertEquals(court.highlight, 1);

  const long = markTargets([("Un texte de mille caractères. ").repeat(60)]);
  assertEquals(long.bold > court.bold, true);
  assertEquals(long.highlight > court.highlight, true);
});

Deno.test("le message de la passe chiffre ce qu'il attend de CE lot", () => {
  const prompt = markPrompt([("Un paragraphe de fiche, assez long pour compter. ").repeat(12)]);
  const target = markTargets([("Un paragraphe de fiche, assez long pour compter. ").repeat(12)]);
  assertEquals(prompt.includes(`${target.bold} termes`), true);
  assertEquals(prompt.includes(`${target.highlight} passages`), true);
});

Deno.test("les textes partent par lots de dix", () => {
  const textes = Array.from({ length: 45 }, (_, index) => `texte ${index}`);
  const lots = batched(textes);
  assertEquals(lots.length, 5);
  assertEquals(lots[0]!.length, 10);
  assertEquals(lots[4]!.length, 5);
  assertEquals(lots.flat(), textes);
});

Deno.test("cleanBlockMarks passe sur tous les textes d'une fiche", () => {
  const blocks: SheetBlock[] = [
    PARAGRAPH("Une entreprise fondée en 2017, issue de==rose| trente-cinq ans de recherche=="),
    { type: "list", ordered: false, items: ["Un **point** net", "Un point **abîmé"] },
  ];
  const cleaned = cleanBlockMarks(blocks);
  assertEquals(cleaned[0], PARAGRAPH("Une entreprise fondée en 2017, issue de trente-cinq ans de recherche"));
  assertEquals(cleaned[1], {
    type: "list",
    ordered: false,
    items: ["Un **point** net", "Un point abîmé"],
  });
});

Deno.test("la consigne de la seconde passe chiffre ce qu'elle doit poser", () => {
  // Mesuré : la passe reposait les surlignages et laissait l'italique à zéro. Elle compte
  // maintenant, et on lui dit où chercher.
  assertEquals(MARK_SYSTEM_PROMPT.includes("le nombre exact de marques attendues"), true);
  assertEquals(MARK_SYSTEM_PROMPT.includes("LA POSE"), true);
  assertEquals(MARK_SYSTEM_PROMPT.includes("IDENTIQUE"), true);
});

Deno.test("textsToMark rend les textes dans l'ordre où la fusion les attend", () => {
  const blocks: SheetBlock[] = [
    { type: "heading", level: 1, text: "Titre" },
    PARAGRAPH("Un paragraphe."),
    { type: "list", ordered: false, items: ["Un", "Deux"] },
    { type: "formula", latex: "E = mc^2", caption: "La légende" },
  ];
  assertEquals(textsToMark(blocks), ["Titre", "Un paragraphe.", "Un", "Deux", "La légende"]);
});

Deno.test("mergeMarked accepte les marques et rien d'autre", () => {
  const blocks = [PARAGRAPH("La Rubisco fixe le carbone."), PARAGRAPH("Le stroma est liquide.")];
  const merged = mergeMarked(blocks, [
    "La **Rubisco** fixe le carbone.",
    // Un mot changé au passage : le bloc garde son texte d'origine.
    "Le **cytoplasme** est liquide.",
  ]);
  assertEquals(merged[0], PARAGRAPH("La **Rubisco** fixe le carbone."));
  assertEquals(merged[1], PARAGRAPH("Le stroma est liquide."));
});

Deno.test("mergeMarked refuse une repasse qui efface des marques", () => {
  // Le cas qui a coûté une fiche : mêmes phrases au caractère près, dix-sept gras en moins.
  const blocks = [PARAGRAPH("La **Rubisco** fixe le **carbone** : ==jaune|c'est l'étape lente==.")];
  const merged = mergeMarked(blocks, ["La Rubisco fixe le carbone : c'est l'étape lente."]);
  assertEquals(merged, blocks);

  // Ajouter est permis, y compris sur un texte déjà marqué.
  const enriched = mergeMarked(blocks, [
    "La **Rubisco** fixe le **carbone** : ==jaune|c'est l'étape *lente*==.",
  ]);
  assertEquals(
    enriched[0],
    PARAGRAPH("La **Rubisco** fixe le **carbone** : ==jaune|c'est l'étape *lente*==."),
  );
});

Deno.test("mergeMarked garde l'original quand la réponse est courte ou mal typée", () => {
  const blocks = [PARAGRAPH("Premier texte."), PARAGRAPH("Second texte.")];
  assertEquals(mergeMarked(blocks, [42]), blocks);
  assertEquals(mergeMarked(blocks, []), blocks);
});

Deno.test("mergeMarked marque les points d'une liste un à un", () => {
  const blocks: SheetBlock[] = [{ type: "list", ordered: true, items: ["Oxydation", "Réduction"] }];
  const merged = mergeMarked(blocks, ["**Oxydation**", "Réduction *partielle*"]);
  assertEquals(merged[0], {
    type: "list",
    ordered: true,
    // Le second a bougé : « partielle » n'était pas dans le texte, il est écarté.
    items: ["**Oxydation**", "Réduction"],
  });
});

Deno.test("mergeMarked laisse la couleur d'un surligneur passer", () => {
  // `stripInlineMarkup` retire `==menthe|` : sans ça, toute couleur serait vue comme un mot
  // ajouté et chaque passage coloré serait écarté.
  const blocks = [PARAGRAPH("Le rendement réel atteint 2 % au mieux.")];
  const merged = mergeMarked(blocks, ["==menthe|Le rendement réel atteint 2 % au mieux.=="]);
  assertEquals(merged[0], PARAGRAPH("==menthe|Le rendement réel atteint 2 % au mieux.=="));
});
