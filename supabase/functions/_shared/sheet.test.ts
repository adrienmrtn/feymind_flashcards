import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { normalizeSheet, SHEET_LIMITS } from "./sheet.ts";
import type { SheetBlock } from "./sheet.ts";

function countMarks(blocks: SheetBlock[]): number {
  const texts = blocks.flatMap((block) => {
    switch (block.type) {
      case "paragraph":
      case "callout":
      case "heading":
        return [block.text];
      case "definition":
        return [block.term, block.text];
      case "steps":
        return block.items;
      default:
        return [];
    }
  });
  return texts.reduce(
    (total, text) => total + Math.floor((text.match(/==/g)?.length ?? 0) / 2),
    0,
  );
}

const paragraph = (text: string): SheetBlock => ({ type: "paragraph", text });

describe("normalizeSheet", () => {
  it("plafonne les passages mis en avant sur toute la fiche", () => {
    const marked = Array.from({ length: 12 }, (_, index) => ({
      type: "paragraph",
      text: `==Passage numéro ${index} marqué== et une suite de phrase pour tenir la longueur.`,
    }));

    const blocks = normalizeSheet(marked);

    assert.equal(blocks.length, 12);
    assert.ok(countMarks(blocks) <= SHEET_LIMITS.highlights);
  });

  // Le garde-fou contre la fiche en accordéon : chaque bloc est peut-être juste, mais une
  // file d'objets encartés ne se lit plus, elle se feuillette.
  it("écarte le cinquième objet d'une file", () => {
    const blocks = normalizeSheet([
      paragraph("Le cycle de l'eau ne perd rien, et c'est ce que la suite va détailler ici."),
      { type: "definition", term: "Évaporation", text: "Passage de l'état liquide à la vapeur." },
      { type: "callout", tone: "attention", text: "Ne confonds pas évaporation et ébullition." },
      { type: "formula", latex: "H_2O" },
      {
        type: "table",
        headers: ["Phase", "Lieu"],
        rows: [["Photochimique", "Thylakoïdes"], ["Non photochimique", "Stroma"]],
      },
      { type: "definition", term: "Condensation", text: "Retour de la vapeur à l'état liquide." },
    ]);

    assert.deepEqual(blocks.map((block) => block.type), [
      "paragraph",
      "definition",
      "callout",
      "formula",
      "table",
    ]);
  });

  it("laisse repartir la file dès qu'un paragraphe ou un titre la coupe", () => {
    const object = { type: "definition" as const, term: "Terme", text: "Ce que le terme désigne." };

    const blocks = normalizeSheet([
      object,
      object,
      paragraph("Une phrase qui relie ce qui précède à ce qui suit, et qui rouvre la page."),
      object,
      object,
      { type: "heading", level: 2, text: "Une sous-partie" },
      object,
    ]);

    assert.deepEqual(blocks.map((block) => block.type), [
      "definition",
      "definition",
      "paragraph",
      "definition",
      "definition",
      "heading",
      "definition",
    ]);
  });

  // Le prompt demande à l'encadré « essentiel » de fermer la fiche : le garde-fou ne doit pas
  // emporter la seule chose qu'on avait exigée parce qu'elle arrive après deux objets.
  it("garde l'encadré essentiel même au bout d'une file", () => {
    const blocks = normalizeSheet([
      paragraph("Le cycle de l'eau ne perd rien, et c'est ce que la suite va détailler ici."),
      {
        type: "table",
        headers: ["Phase", "Lieu"],
        rows: [["Photochimique", "Thylakoïdes"], ["Non photochimique", "Stroma"]],
      },
      { type: "formula", latex: "H_2O" },
      { type: "callout", tone: "essentiel", text: "Le cycle est fermé : la quantité ne varie pas." },
    ]);

    assert.deepEqual(blocks.map((block) => block.type), [
      "paragraph",
      "table",
      "formula",
      "callout",
    ]);
  });

  it("n'épargne que l'essentiel, pas les autres encadrés", () => {
    const blocks = normalizeSheet([
      { type: "definition", term: "Un", text: "Ce que le premier terme désigne exactement." },
      { type: "definition", term: "Deux", text: "Ce que le deuxième terme désigne exactement." },
      { type: "definition", term: "Trois", text: "Ce que le troisième terme désigne exactement." },
      { type: "definition", term: "Quatre", text: "Ce que le quatrième terme désigne exactement." },
      { type: "callout", tone: "astuce", text: "Un moyen de retenir la chose, en une phrase." },
    ]);

    assert.equal(blocks.length, SHEET_LIMITS.objectRun);
    assert.equal(blocks.at(-1)?.type, "definition");
  });

  it("compte les objets d'affilée quel que soit leur type", () => {
    const blocks = normalizeSheet([
      { type: "definition", term: "Un", text: "Ce que le premier terme désigne exactement." },
      { type: "definition", term: "Deux", text: "Ce que le deuxième terme désigne exactement." },
      { type: "definition", term: "Trois", text: "Ce que le troisième terme désigne exactement." },
      { type: "definition", term: "Quatre", text: "Ce que le quatrième terme désigne exactement." },
      { type: "definition", term: "Cinq", text: "Ce que le cinquième terme désigne exactement." },
    ]);

    assert.equal(blocks.length, SHEET_LIMITS.objectRun);
  });

  it("garde une figure localisée et jette celle sans page ni image", () => {
    const blocks = normalizeSheet([
      paragraph("Le cycle de Krebs oxyde l'acétyl-CoA dans la matrice mitochondriale."),
      {
        type: "figure",
        caption: "Cycle de Krebs",
        page: 2,
        crop: { x: 0.1, y: 0.2, w: 0.8, h: 0.4 },
      },
      { type: "figure", caption: "Sans ancrage" },
    ]);

    assert.equal(blocks.filter((block) => block.type === "figure").length, 1);
  });

  it("garde l'image d'une figure dense, au-delà de 400 000 caractères", () => {
    const image = "data:image/jpeg;base64," + "A".repeat(500_000);
    const blocks = normalizeSheet([
      paragraph("Le cycle de Krebs oxyde l'acétyl-CoA dans la matrice mitochondriale."),
      {
        type: "figure",
        caption: "Cycle de Krebs",
        page: 1,
        image,
      },
    ]);
    const figure = blocks.find((block) => block.type === "figure");
    assert.equal(figure?.type === "figure" ? figure.image : undefined, image);
  });
});
