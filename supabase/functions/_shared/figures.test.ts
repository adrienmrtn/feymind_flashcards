import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { figuresBrief, injectUnusedFigures, parseExtractedFigures } from "./figures.ts";
import type { SheetBlock } from "./sheet.ts";

describe("parseExtractedFigures", () => {
  it("relève les lignes FIGURE et ignore le reste", () => {
    const figures = parseExtractedFigures(`
Page 1 : un titre et du texte courant.
FIGURE page=1 x=0.10 y=0.22 w=0.80 h=0.36 caption=Cycle de Krebs
Page 2 : aucun visuel notable
FIGURE page=2 x=0,05 y=0,40 w=0,90 h=0,30 caption=Courbe de croissance
`);

    assert.equal(figures.length, 2);
    assert.equal(figures[0]?.page, 1);
    assert.equal(figures[0]?.caption, "Cycle de Krebs");
    assert.equal(figures[0]?.crop.x, 0.1);
    assert.equal(figures[1]?.crop.y, 0.4);
  });

  it("écarte une ligne trop étroite ou sans légende", () => {
    const figures = parseExtractedFigures(`
FIGURE page=1 x=0.1 y=0.1 w=0.02 h=0.02 caption=Trop petite
FIGURE page=1 x=0.1 y=0.1 w=0.5 h=0.5 caption=ab
`);
    assert.equal(figures.length, 0);
  });
});

describe("figuresBrief", () => {
  it("est vide sans figure, et nomme celles qu'il a", () => {
    assert.equal(figuresBrief([]), "");
    const brief = figuresBrief([
      { page: 2, crop: { x: 0.1, y: 0.2, w: 0.8, h: 0.4 }, caption: "Cycle de Krebs" },
    ]);
    assert.match(brief, /FIGURES EXTRAITES/);
    assert.match(brief, /Cycle de Krebs/);
    assert.match(brief, /page=2/);
  });
});

describe("injectUnusedFigures", () => {
  const extracted = [
    { page: 1, crop: { x: 0.1, y: 0.2, w: 0.8, h: 0.4 }, caption: "Cycle de Krebs" },
  ];

  it("n'ajoute rien si la figure est déjà dans la fiche", () => {
    const blocks: SheetBlock[] = [
      { type: "paragraph", text: "Le cycle de Krebs oxyde l'acétyl-CoA dans la matrice." },
      { type: "figure", caption: "Cycle de Krebs", page: 1 },
    ];
    assert.equal(injectUnusedFigures(blocks, extracted).length, 2);
  });

  it("glisse la figure oubliée après le premier paragraphe", () => {
    const blocks: SheetBlock[] = [
      { type: "paragraph", text: "Le cycle de Krebs oxyde l'acétyl-CoA dans la matrice." },
      { type: "callout", tone: "essentiel", text: "C'est le carrefour du catabolisme." },
    ];
    const next = injectUnusedFigures(blocks, extracted);
    assert.deepEqual(next.map((block) => block.type), ["paragraph", "figure", "callout"]);
    assert.equal(next[1]?.type === "figure" ? next[1].caption : "", "Cycle de Krebs");
  });
});
