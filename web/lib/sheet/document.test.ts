/**
 * L'aller-retour de la fiche : blocs → document → blocs.
 *
 * C'est le seul endroit du produit où une erreur **efface le travail de l'étudiant** : un
 * retour qui perd une marque perd la marque à l'enregistrement, et personne ne s'en aperçoit
 * avant la veille de l'épreuve. Les tests portent donc sur l'aller-retour complet, pas sur
 * chaque moitié prise à part.
 *
 * Le retour lit un arbre `NodeLike`. Les objets ci-dessous en sont un, écrit à la main : le
 * DOM n'existe pas dans un test Node, et le faire venir pour ça coûterait plus cher que de
 * décrire trois nœuds.
 */

import { describe, expect, it } from "vitest";

import { blocksToHtml, htmlToBlocks, readInline, type NodeLike } from "./document";

function text(value: string): NodeLike {
  return { nodeType: 3, nodeName: "#text", textContent: value, childNodes: [] };
}

function el(
  name: string,
  children: NodeLike[],
  attributes: Record<string, string> = {},
): NodeLike {
  return {
    nodeType: 1,
    nodeName: name.toUpperCase(),
    textContent: children.map((child) => child.textContent ?? "").join(""),
    childNodes: children,
    getAttribute: (key: string) => attributes[key] ?? null,
  };
}

describe("des blocs vers le document", () => {
  it("écrit un titre, un paragraphe, une liste et une formule", () => {
    const html = blocksToHtml([
      { type: "heading", level: 1, text: "Le cycle de l'eau" },
      { type: "paragraph", text: "L'eau circule entre les **réservoirs**." },
      { type: "list", ordered: true, items: ["Évaporation", "Condensation"] },
      { type: "formula", latex: "E = mc^2", caption: "L'énergie de masse" },
    ]);

    expect(html).toContain("<h1>Le cycle de l'eau</h1>");
    expect(html).toContain("<strong>réservoirs</strong>");
    expect(html).toContain("<ol><li>Évaporation</li><li>Condensation</li></ol>");
    expect(html).toContain('data-latex="E = mc^2"');
    expect(html).toContain('data-caption="L&#039;énergie de masse"'.replace("&#039;", "'"));
  });

  it("pose une couleur de surlignage sur la marque", () => {
    const html = blocksToHtml([{ type: "paragraph", text: "Retiens ==menthe|ceci== demain." }]);
    expect(html).toContain('<mark data-hl="menthe">ceci</mark>');
  });

  it("donne une hauteur à un bloc vide", () => {
    // Sans le saut de ligne, on ne peut plus poser le curseur dans le paragraphe, donc plus
    // jamais le remplir.
    expect(blocksToHtml([{ type: "heading", level: 2, text: "" }])).toBe("<h2><br></h2>");
  });

  it("échappe ce qui casserait le document", () => {
    const html = blocksToHtml([{ type: "paragraph", text: "Si a < b alors <script>." }]);
    expect(html).toContain("a &lt; b");
    expect(html).not.toContain("<script>");
  });
});

describe("du document vers les blocs", () => {
  it("relit les marques posées dans l'arbre", () => {
    const paragraph = el("p", [
      text("L'eau circule entre les "),
      el("strong", [text("réservoirs")]),
      text(" de la "),
      el("mark", [text("planète")], { "data-hl": "bleu" }),
      text("."),
    ]);

    expect(readInline(paragraph)).toBe(
      "L'eau circule entre les **réservoirs** de la ==bleu|planète==.",
    );
  });

  it("fait l'aller-retour sans rien perdre", () => {
    const blocks = [
      { type: "heading" as const, level: 1, text: "Le cycle de l'eau" },
      {
        type: "paragraph" as const,
        text: "L'eau circule entre les **réservoirs**, et ==rose|le Soleil la porte==.",
      },
      { type: "list" as const, ordered: false, items: ["Les océans portent 97 %", "Les glaciers 2 %"] },
    ];

    const root = el("div", [
      el("h1", [text("Le cycle de l'eau")]),
      el("p", [
        text("L'eau circule entre les "),
        el("strong", [text("réservoirs")]),
        text(", et "),
        el("mark", [text("le Soleil la porte")], { "data-hl": "rose" }),
        text("."),
      ]),
      el("ul", [
        el("li", [text("Les océans portent 97 %")]),
        el("li", [text("Les glaciers 2 %")]),
      ]),
    ]);

    expect(htmlToBlocks(root)).toEqual(blocks);
  });

  it("garde le LaTeX d'une formule plutôt que son rendu", () => {
    const root = el("div", [
      el("div", [text("E = mc²")], { "data-formula": "", "data-latex": "E = mc^2", "data-caption": "" }),
    ]);

    expect(htmlToBlocks(root)).toEqual([{ type: "formula", latex: "E = mc^2" }]);
  });

  it("ramène au paragraphe ce qui vient d'un collage", () => {
    // Coller depuis un traitement de texte apporte des div, des span de style et des tableaux.
    // Le texte reste, le vocabulaire de la fiche ne s'étend pas.
    const root = el("div", [
      el("blockquote", [text("Une citation collée depuis une page web.")]),
      el("table", [el("tr", [el("td", [text("Une cellule collée depuis un tableur.")])])]),
    ]);

    expect(htmlToBlocks(root)).toEqual([
      { type: "paragraph", text: "Une citation collée depuis une page web." },
      { type: "paragraph", text: "Une cellule collée depuis un tableur." },
    ]);
  });

  it("jette un bloc vide plutôt que d'enregistrer du blanc", () => {
    const root = el("div", [el("p", [el("br", [])]), el("h2", [text("")])]);
    expect(htmlToBlocks(root)).toEqual([]);
  });
});
