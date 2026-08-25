import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { ensureHighlights, markPassage, normalizeSheet, SHEET_LIMITS } from "./sheet.ts";
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

describe("markPassage", () => {
  it("surligne la phrase qui porte un terme en gras", () => {
    const marked = markPassage(
      "L'eau circule sans jamais quitter la planète, et cette boucle est fermée. " +
        "La **condensation** transforme la vapeur en gouttelettes autour de noyaux minuscules.",
    );

    assert.ok(marked);
    assert.match(marked!, /==La \*\*condensation\*\*/);
    // La ponctuation finale reste hors de la marque : on surligne une phrase, pas un point.
    assert.match(marked!, /minuscules==\./);
  });

  it("ramène une phrase interminable à sa première proposition", () => {
    const long = "La photosynthèse convertit l'énergie lumineuse en énergie chimique, " +
      "ce qui suppose une chaîne de transporteurs, des pigments capables d'absorber " +
      "certaines longueurs d'onde, et une organisation membranaire que seuls les " +
      "thylakoïdes des chloroplastes rendent possible dans la cellule végétale.";

    const marked = markPassage(long);

    assert.ok(marked);
    const passage = marked!.slice(marked!.indexOf("==") + 2, marked!.lastIndexOf("=="));
    assert.ok(passage.length <= 170, `passage de ${passage.length} caractères`);
    assert.ok(passage.length >= 40);
  });

  it("ne touche pas un texte déjà surligné", () => {
    assert.equal(markPassage("Un texte ==déjà marqué== et suffisamment long pour compter."), null);
  });

  it("laisse tomber un texte trop court pour porter une marque", () => {
    assert.equal(markPassage("Trop court."), null);
  });
});

describe("ensureHighlights", () => {
  it("garantit le plancher sur une fiche que le modèle a rendue sans une seule marque", () => {
    const blocks: SheetBlock[] = [
      paragraph(
        "L'eau change d'état sans jamais quitter la planète, et c'est tout le sujet du chapitre.",
      ),
      { type: "heading", level: 1, text: "Les trois temps" },
      paragraph(
        "L'évaporation précède la condensation, puis la précipitation referme la boucle du cycle.",
      ),
      {
        type: "definition",
        term: "Condensation",
        text: "Passage de la vapeur à l'état liquide, autour de noyaux de condensation minuscules.",
      },
      {
        type: "callout",
        tone: "essentiel",
        text: "Le cycle de l'eau est fermé : la quantité totale d'eau sur Terre ne varie pas.",
      },
    ];

    const marked = ensureHighlights(blocks);

    assert.equal(countMarks(blocks), 0);
    assert.ok(countMarks(marked) >= SHEET_LIMITS.minimumHighlights);
  });

  it("commence par l'encadré essentiel", () => {
    const blocks: SheetBlock[] = [
      {
        type: "callout",
        tone: "essentiel",
        text: "La quantité totale d'eau sur Terre ne varie pas : le cycle est fermé.",
      },
      paragraph("L'évaporation précède la condensation, puis la précipitation referme la boucle."),
    ];

    const marked = ensureHighlights(blocks, 1);

    assert.match((marked[0] as { text: string }).text, /==/);
    assert.doesNotMatch((marked[1] as { text: string }).text, /==/);
  });

  it("ne touche pas une fiche déjà correctement surlignée", () => {
    const blocks: SheetBlock[] = [
      paragraph("==L'eau change d'état== sans jamais quitter la planète, et c'est le sujet."),
      paragraph("==L'évaporation précède la condensation== puis la précipitation referme."),
    ];

    assert.deepEqual(ensureHighlights(blocks, 2), blocks);
  });

  it("ne surligne ni les titres ni les tableaux", () => {
    const blocks: SheetBlock[] = [
      { type: "heading", level: 1, text: "Un titre qui pourrait tenir une phrase entière ici" },
      {
        type: "table",
        headers: ["Phase", "Lieu"],
        rows: [["Photochimique", "Thylakoïdes"], ["Non photochimique", "Stroma"]],
      },
    ];

    assert.deepEqual(ensureHighlights(blocks), blocks);
  });
});

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
  it("écarte le troisième objet d'une file", () => {
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
    ]);

    assert.deepEqual(blocks.map((block) => block.type), [
      "paragraph",
      "definition",
      "callout",
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
      { type: "callout", tone: "astuce", text: "Un moyen de retenir la chose, en une phrase." },
    ]);

    assert.equal(blocks.length, SHEET_LIMITS.objectRun);
  });

  it("compte les objets d'affilée quel que soit leur type", () => {
    const blocks = normalizeSheet([
      { type: "definition", term: "Un", text: "Ce que le premier terme désigne exactement." },
      { type: "definition", term: "Deux", text: "Ce que le deuxième terme désigne exactement." },
      { type: "definition", term: "Trois", text: "Ce que le troisième terme désigne exactement." },
    ]);

    assert.equal(blocks.length, SHEET_LIMITS.objectRun);
  });
});
