/**
 * Le balisage en ligne.
 *
 * Les cas qui comptent sont ceux du **délimiteur seul** : un cours de statistiques écrit
 * « p < 0,05 * » pour dire « significatif », et une astérisque orpheline ne doit ni passer en
 * italique ni disparaître. C'est la raison d'être du parseur, plutôt qu'une expression
 * régulière.
 */

import { describe, expect, it } from "vitest";

import { containsInlineMarkup, parseInlineMarkup, toInlineMarkup } from "../src/sheet/markup";
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

describe("les couleurs de surlignage", () => {
  it("marque en jaune par défaut", () => {
    const spans = parseInlineMarkup("Ce qui compte est ==ici==.");
    const marked = spans.find((span) => span.highlighted);
    expect(marked?.text).toBe("ici");
    expect(marked?.highlight).toBe("jaune");
  });

  it("lit une couleur nommée avant la barre", () => {
    const spans = parseInlineMarkup("Retiens ==menthe|la condensation== pour demain.");
    const marked = spans.find((span) => span.highlighted);
    expect(marked?.text).toBe("la condensation");
    expect(marked?.highlight).toBe("menthe");
  });

  it("laisse une barre ordinaire tranquille", () => {
    // Un cours d'informatique écrit « a | b » sans vouloir colorer quoi que ce soit.
    const spans = parseInlineMarkup("On note ==a | b== la disjonction.");
    const marked = spans.find((span) => span.highlighted);
    expect(marked?.text).toBe("a | b");
    expect(marked?.highlight).toBe("jaune");
  });

  it("fait l'aller-retour sans rien perdre", () => {
    const source = "**Le cycle** de ==bleu|l'eau== et *ses* phases, $E = mc^2$.";
    expect(toInlineMarkup(parseInlineMarkup(source))).toBe(source);
  });
});

describe("le barré", () => {
  it("se lit comme les autres marques et se cumule avec elles", () => {
    const spans = parseInlineMarkup("On avait noté ~~**mille**~~ et c'était faux.");

    expect(spans.find((span) => span.strike)?.text).toBe("mille");
    expect(spans.find((span) => span.strike)?.bold).toBe(true);
  });

  it("laisse un tilde seul tranquille", () => {
    // « ~ » est un opérateur en statistiques et une approximation partout ailleurs ; une
    // marque sans fermeture reste un caractère, comme pour l'astérisque.
    expect(parseInlineMarkup("x ~ N(0, 1)").some((span) => span.strike)).toBe(false);
    expect(containsInlineMarkup("environ ~~ deux")).toBe(false);
  });

  it("revient au texte balisé qu'il avait", () => {
    // L'ordre d'écriture est celui du module : gras dehors, puis italique, puis barré,
    // puis surlignage. C'est ce que l'éditeur réécrit à chaque enregistrement.
    const source = "On disait *~~ceci~~* avant.";

    expect(toInlineMarkup(parseInlineMarkup(source))).toBe(source);
  });
});

describe("la taille d'un fragment", () => {
  it("se lit et se réécrit", () => {
    const spans = parseInlineMarkup("Le ^^grand|point clé^^ et un ^^petit|aparté^^.");
    expect(spans.map((span) => [span.text, span.size])).toEqual([
      ["Le ", null],
      ["point clé", "grand"],
      [" et un ", null],
      ["aparté", "petit"],
      [".", null],
    ]);
    expect(toInlineMarkup(spans)).toBe("Le ^^grand|point clé^^ et un ^^petit|aparté^^.");
  });

  it("se cumule avec les autres marques", () => {
    const spans = parseInlineMarkup("^^grand|**très** important^^");
    expect(spans[0]).toMatchObject({ text: "très", bold: true, size: "grand" });
    expect(spans[1]).toMatchObject({ text: " important", bold: false, size: "grand" });
  });

  it("laisse tranquilles deux accents circonflexes qui ne disent rien", () => {
    // Un cours de maths écrit « a^^2 » à la main : ce n'est pas une marque, et rien ne doit
    // disparaître du texte.
    expect(parseInlineMarkup("a^^2 vaut b").map((span) => span.text)).toEqual(["a^^2 vaut b"]);
    expect(parseInlineMarkup("x^^inconnu|y^^").map((span) => span.text)).toEqual([
      "x^^inconnu|y^^",
    ]);
  });

  it("ne part pas dans le texte envoyé au modèle", () => {
    expect(stripInlineMarkup("Le ^^grand|point clé^^ compte.")).toBe("Le point clé compte.");
  });
});
