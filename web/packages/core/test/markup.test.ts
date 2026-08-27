/**
 * Le balisage en ligne.
 *
 * Les cas qui comptent sont ceux du **délimiteur seul** : un cours de statistiques écrit
 * « p < 0,05 * » pour dire « significatif », et une astérisque orpheline ne doit ni passer en
 * italique ni disparaître. C'est la raison d'être du parseur, plutôt qu'une expression
 * régulière.
 */

import { describe, expect, it } from "vitest";

import { containsInlineMarkup, parseInlineMarkup } from "../src/sheet/markup";
import { stripInlineMarkup } from "../src/sheet/canonical";

function rendered(source: string) {
  return parseInlineMarkup(source).map((span) => ({
    text: span.text,
    ...(span.bold ? { bold: true } : {}),
    ...(span.italic ? { italic: true } : {}),
    ...(span.highlighted ? { highlighted: true } : {}),
    ...(span.math ? { math: true } : {}),
  }));
}

describe("les quatre marques", () => {
  it("met un terme en gras", () => {
    expect(rendered("La **mitose** est une division.")).toEqual([
      { text: "La " },
      { text: "mitose", bold: true },
      { text: " est une division." },
    ]);
  });

  it("met une nuance en italique", () => {
    expect(rendered("Le terme *sensu stricto* désigne…")).toEqual([
      { text: "Le terme " },
      { text: "sensu stricto", italic: true },
      { text: " désigne…" },
    ]);
  });

  it("surligne l'essentiel", () => {
    expect(rendered("==L'eau circule en boucle fermée.==")).toEqual([
      { text: "L'eau circule en boucle fermée.", highlighted: true },
    ]);
  });

  it("garde le LaTeX brut d'une formule", () => {
    expect(rendered("On a $E = mc^2$ ici.")).toEqual([
      { text: "On a " },
      { text: "E = mc^2", math: true },
      { text: " ici." },
    ]);
  });
});

describe("les délimiteurs seuls", () => {
  it("laisse une astérisque orpheline telle quelle", () => {
    expect(rendered("Significatif à p < 0,05 *")).toEqual([{ text: "Significatif à p < 0,05 *" }]);
  });

  it("avale un gras non fermé, comme l'iPhone", () => {
    // **Ce cas n'est pas celui qu'on attendrait, et c'est voulu.** Un `**` non fermé n'est pas
    // laissé littéral : la première astérisque ouvre une italique - sa fermeture est la
    // seconde astérisque, qui n'est pas suivie d'une autre et compte donc pour elle-même - et
    // les deux marques disparaissent en laissant un fragment vide.
    //
    // C'est exactement ce que fait `SheetMarkup.spans` côté iOS, et c'est la seule raison de
    // le reproduire ici : une fiche rendue autrement sur le web serait une fiche différente.
    // Le jour où ça se corrige, ça se corrige des deux côtés, dans la même version.
    expect(rendered("Un **début sans fin")).toEqual([
      { text: "Un " },
      { text: "début sans fin" },
    ]);
  });

  it("laisse une seule astérisque non fermée tel quel", () => {
    expect(rendered("Un *début sans fin")).toEqual([{ text: "Un *début sans fin" }]);
  });

  it("laisse un surlignage non fermé tel quel", () => {
    expect(rendered("Deux == trois")).toEqual([{ text: "Deux == trois" }]);
  });

  it("laisse un dollar seul tel quel", () => {
    expect(rendered("Le coût est de 30 $ par mois")).toEqual([
      { text: "Le coût est de 30 $ par mois" },
    ]);
  });
});

describe("les priorités", () => {
  it("le gras passe avant l'italique", () => {
    expect(rendered("**gras** et *penché*")).toEqual([
      { text: "gras", bold: true },
      { text: " et " },
      { text: "penché", italic: true },
    ]);
  });

  it("une formule est opaque au balisage", () => {
    // `a^*` dans une expression n'est pas de l'italique.
    expect(rendered("La borne $a^* + b$ est atteinte.")).toEqual([
      { text: "La borne " },
      { text: "a^* + b", math: true },
      { text: " est atteinte." },
    ]);
  });

  it("cumule le gras et le surlignage", () => {
    expect(rendered("==Retenir le **terme** exact==")).toEqual([
      { text: "Retenir le ", highlighted: true },
      { text: "terme", bold: true, highlighted: true },
      { text: " exact", highlighted: true },
    ]);
  });
});

describe("détection", () => {
  it("reconnaît un texte balisé", () => {
    expect(containsInlineMarkup("La **mitose**")).toBe(true);
    expect(containsInlineMarkup("Une phrase nue.")).toBe(false);
    expect(containsInlineMarkup("p < 0,05 *")).toBe(false);
  });
});

describe("la mise à plat reste celle du serveur", () => {
  it("recolle le texte des fragments sur ce que le serveur écrirait", () => {
    // Les deux chemins doivent tomber sur la même phrase : le serveur a écrit le
    // `context_text` enregistré en base, et le site ne peut pas en produire un autre.
    const source = "La **mitose** est une *division* : ==une cellule en deux==. $n = 2$";

    const joined = parseInlineMarkup(source)
      .map((span) => span.text)
      .join("")
      .replace(/\s{2,}/g, " ")
      .trim();

    expect(joined).toBe(stripInlineMarkup(source));
  });
});
