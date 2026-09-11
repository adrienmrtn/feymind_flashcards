import { assertEquals } from "jsr:@std/assert@1";

import type { SheetBlock } from "../_shared/sheet.ts";
import { countMarks, mergeMarked, needsMarkPass, textsToMark } from "./marks.ts";

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

Deno.test("la seconde passe se déclenche sur le zéro, pas sur la rareté", () => {
  const marked = [
    PARAGRAPH("La **Rubisco** fixe le carbone, ==jaune|et c'est l'étape limitante==."),
    PARAGRAPH("Le terme *stroma* désigne le compartiment, pas la membrane."),
  ];
  assertEquals(needsMarkPass(marked), false);

  // Une seule sorte manquante suffit : c'est la page sans relief que les étudiants signalent.
  assertEquals(needsMarkPass([PARAGRAPH("La **Rubisco** fixe le carbone, sans plus.")]), true);
  assertEquals(needsMarkPass([]), false);
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
