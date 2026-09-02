import { describe, expect, it } from "vitest";

import { canTypeset, typesetMath } from "./typeset";

describe("typesetMath", () => {
  it("compose une fraction, avec sa barre et ses deux étages", () => {
    const out = typesetMath("\\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}");

    expect(out.kind).toBe("typeset");
    if (out.kind !== "typeset") return;
    // Une vraie barre de fraction, pas une barre oblique.
    expect(out.html).toContain("frac-line");
    expect(out.html).not.toContain("(-b ± √");
  });

  it("rend aussi le MathML, pour les lecteurs d'écran", () => {
    const out = typesetMath("E = mc^2");

    expect(out.kind).toBe("typeset");
    if (out.kind !== "typeset") return;
    expect(out.html).toContain("<math");
    expect(out.html).toContain("katex-mathml");
  });

  it("passe en display quand on le demande", () => {
    const inline = typesetMath("\\sum_{i=1}^{n} i");
    const display = typesetMath("\\sum_{i=1}^{n} i", { display: true });

    expect(inline.kind).toBe("typeset");
    expect(display.kind).toBe("typeset");
    if (inline.kind !== "typeset" || display.kind !== "typeset") return;
    expect(display.html).toContain("katex-display");
    expect(inline.html).not.toContain("katex-display");
  });

  it("retombe sur la transposition Unicode quand le LaTeX est cassé", () => {
    const out = typesetMath("\\frac{1}{");

    expect(out.kind).toBe("transposed");
    if (out.kind !== "transposed") return;
    expect(out.text.length).toBeGreaterThan(0);
    expect(out.text).not.toContain("\\frac");
  });

  it("retombe aussi sur une commande qui n'existe pas", () => {
    const out = typesetMath("\\pasunecommande{x}");
    expect(out.kind).toBe("transposed");
  });

  it("garde le plancher d'avant : les indices deviennent des indices", () => {
    // Le repli est exactement `latexToUnicode`, celui que l'iPhone partage.
    const out = typesetMath("H_2O \\pasunecommande");
    expect(out.kind).toBe("transposed");
    if (out.kind !== "transposed") return;
    expect(out.text).toContain("H₂O");
  });

  it("ne rend rien pour un fragment vide", () => {
    expect(typesetMath("   ")).toEqual({ kind: "transposed", text: "" });
  });

  it("n'écrit aucun lien dans la page", () => {
    // `trust: false` ne fait pas échouer `\href` : KaTeX le compose comme du
    // texte, sans balise. C'est ce qu'on veut vérifier, pas le repli.
    const out = typesetMath("\\href{https://exemple.fr}{clique}");
    const rendered = out.kind === "typeset" ? out.html : out.text;

    expect(rendered).not.toContain("<a ");
    expect(rendered).not.toContain("href=");
  });

  it("échappe le HTML d'un \\text au lieu de le laisser passer", () => {
    // Le texte d'une fiche est écrit par un modèle et transite par la base :
    // il ne doit pas pouvoir ouvrir une balise, même une fois échappé et
    // recollé dans la page par `dangerouslySetInnerHTML`.
    const out = typesetMath("\\text{<img src=x onerror=alert(1)>}");
    const rendered = out.kind === "typeset" ? out.html : out.text;

    expect(rendered).not.toContain("<img");
    expect(rendered).not.toContain("<script");
    if (out.kind === "typeset") expect(out.html).toContain("&lt;img");
  });

  it("compose ce qu'un cours de sciences écrit vraiment", () => {
    const real = [
      "H_2O",
      "\\Delta v = a \\times t",
      "x \\in \\mathbb{R}",
      "\\int_0^1 x^2 \\, dx",
      "\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}",
      "\\lim_{x \\to 0} \\frac{\\sin x}{x} = 1",
      "\\alpha + \\beta \\leq \\pi",
      "CO_2 + H_2O \\rightarrow H_2CO_3",
    ];

    for (const latex of real) {
      expect(canTypeset(latex), latex).toBe(true);
    }
  });
});
