import type { SheetBlock } from "@micabo/core";
import { describe, expect, it } from "vitest";

import { joinChapters, replaceChapter, splitChapters } from "./chapters";

/**
 * **Le découpage en chapitres, et la propriété dont tout l'écran dépend.**
 *
 * Un chapitre se modifie seul, dans son propre éditeur, et la fiche entière se réécrit à
 * partir de tous les chapitres. Si le recollage n'est pas l'inverse exact du découpage, une
 * faute de frappe corrigée dans la deuxième partie réécrit la fiche de travers — et c'est le
 * genre de perte qu'on ne voit qu'après la synchro.
 */
const FICHE: SheetBlock[] = [
  { type: "paragraph", text: "La crise de 1929 éclate à New York et gagne l'Europe en deux ans." },
  { type: "heading", level: 1, text: "Les causes de la crise" },
  { type: "paragraph", text: "Les industries produisent plus que les ménages ne peuvent acheter." },
  { type: "heading", level: 2, text: "La surproduction" },
  { type: "list", ordered: false, items: ["Les prix agricoles chutent", "Les salaires stagnent"] },
  { type: "heading", level: 1, text: "Les conséquences sociales" },
  { type: "paragraph", text: "Le chômage de masse s'installe dans les pays industrialisés." },
];

describe("splitChapters", () => {
  it("ouvre un chapitre à chaque titre de partie", () => {
    const chapters = splitChapters(FICHE);

    expect(chapters).toHaveLength(3);
    expect(chapters.map((c) => c.title)).toEqual([
      null,
      "Les causes de la crise",
      "Les conséquences sociales",
    ]);
    expect(chapters.map((c) => c.index)).toEqual([0, 1, 2]);
  });

  it("n'ouvre pas de chapitre sur un titre de sous-partie", () => {
    const chapters = splitChapters(FICHE);

    expect(chapters[1]!.blocks).toHaveLength(4);
    expect(chapters[1]!.blocks).toContainEqual({
      type: "heading",
      level: 2,
      text: "La surproduction",
    });
  });

  it("laisse le titre dans le texte du chapitre", () => {
    const chapters = splitChapters(FICHE);

    expect(chapters[1]!.blocks[0]).toEqual({
      type: "heading",
      level: 1,
      text: "Les causes de la crise",
    });
  });

  it("affiche le titre sans son balisage, et garde le bloc tel quel", () => {
    const chapters = splitChapters([
      { type: "heading", level: 1, text: "La **réplication** de l'ADN" },
      { type: "paragraph", text: "Elle se déroule en trois temps, chacun porté par une enzyme." },
    ]);

    expect(chapters[0]!.title).toBe("La réplication de l'ADN");
    expect(chapters[0]!.blocks[0]).toEqual({
      type: "heading",
      level: 1,
      text: "La **réplication** de l'ADN",
    });
  });

  it("n'a qu'un chapitre quand la fiche n'a pas de plan", () => {
    const nue: SheetBlock[] = [
      { type: "paragraph", text: "Le cours tient en deux paragraphes, et il n'a pas de plan." },
      { type: "paragraph", text: "Le second dit ce que le premier laissait entendre." },
    ];
    const chapters = splitChapters(nue);

    expect(chapters).toHaveLength(1);
    expect(chapters[0]!.title).toBeNull();
    expect(joinChapters(chapters)).toEqual(nue);
  });

  it("ne pose pas de chapitre vide devant une fiche qui ouvre sur un titre", () => {
    const chapters = splitChapters([
      { type: "heading", level: 1, text: "Première partie" },
      { type: "paragraph", text: "Le cours commence par son premier titre de partie." },
    ]);

    expect(chapters).toHaveLength(1);
    expect(chapters[0]!.title).toBe("Première partie");
  });

  it("ne fait aucun chapitre d'une fiche vide", () => {
    expect(splitChapters([])).toEqual([]);
    expect(joinChapters([])).toEqual([]);
  });
});

describe("joinChapters", () => {
  it("est l'inverse exact de splitChapters", () => {
    expect(joinChapters(splitChapters(FICHE))).toEqual(FICHE);
  });
});

describe("replaceChapter", () => {
  it("ne réécrit que son propre chapitre", () => {
    const chapters = splitChapters(FICHE);
    const corrige: SheetBlock[] = [
      { type: "heading", level: 1, text: "Les causes de la crise" },
      { type: "paragraph", text: "Les industries produisent plus que les ménages n'absorbent." },
    ];

    const next = replaceChapter(chapters, 1, corrige);

    expect(next.slice(0, 1)).toEqual(FICHE.slice(0, 1));
    expect(next.slice(-2)).toEqual(FICHE.slice(-2));
    expect(next).toContainEqual(corrige[1]);
  });

  it("ne touche à rien pour un chapitre qui n'existe plus", () => {
    expect(replaceChapter(splitChapters(FICHE), 9, [])).toEqual(FICHE);
  });
});
