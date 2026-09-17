/**
 * **Le découpeur de pavés.**
 *
 * La consigne de longueur pousse le modèle à allonger, et il n'a que deux façons de le
 * faire : des blocs de plus, ou des phrases de plus. La seconde ne lui coûte rien, alors il
 * la prend, et la fiche sort avec des paragraphes de six cents caractères — treize lignes
 * d'iPhone d'un seul tenant, qu'on ne relit pas.
 *
 * Le prompt le dit maintenant, et `splitParagraph` le tient. Ce qui est vérifié ici n'est pas
 * qu'il coupe, mais **qu'il coupe sans abîmer** : pas au milieu d'une phrase, pas dans une
 * formule, pas entre deux marqueurs, et sans perdre un mot en route.
 */

import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

import {
  SHEET_LIMITS,
  normalizeSheet,
  restoreLatexCommands,
  splitParagraph,
} from "../src/sheet/canonical";

/** Huit phrases d'environ quatre-vingt-dix caractères : le pavé type d'une fiche. */
const PAVE = [
  "La seconde industrialisation commence en 1897 et court jusqu'à la veille de la guerre.",
  "Les États-Unis et l'Allemagne y deviennent les centres majeurs de l'innovation technique.",
  "Le Royaume-Uni, qui dominait la première industrialisation, perd son avance relative.",
  "Les industries chimiques et électriques y prennent la place de la sidérurgie et du textile.",
  "L'aspirine déposée par Bayer en 1899 témoigne de la vigueur de la recherche appliquée.",
  "Les grands magasins comme Le Bon Marché font baisser les prix unitaires et montent la consommation.",
  "Schumpeter théorise ces vagues d'innovation sous le nom de cycles économiques longs.",
  "La croissance reste soutenue malgré des crises sectorielles en Allemagne et aux États-Unis.",
].join(" ");

describe("splitParagraph", () => {
  it("laisse tranquille un paragraphe de longueur normale", () => {
    const court = "La crise de 1929 éclate à New York et gagne l'Europe en moins de deux ans.";

    expect(court.length).toBeLessThan(SHEET_LIMITS.paragraphChars);
    expect(splitParagraph(court)).toEqual([court]);
  });

  it("coupe un pavé en plusieurs paragraphes", () => {
    expect(PAVE.length).toBeGreaterThan(SHEET_LIMITS.paragraphChars);

    const parts = splitParagraph(PAVE);

    expect(parts.length).toBeGreaterThan(1);
    // Recollés, ils redonnent le texte : le découpeur ne réécrit rien.
    expect(parts.join(" ")).toBe(PAVE);
  });

  it("ne coupe qu'à une fin de phrase", () => {
    for (const part of splitParagraph(PAVE)) {
      expect(part).toMatch(/[.!?…]$/);
      expect(part[0]).toBe(part[0]!.toLocaleUpperCase());
    }
  });

  it("ne laisse pas de queue d'une demi-ligne", () => {
    for (const part of splitParagraph(PAVE)) {
      expect(part.length).toBeGreaterThanOrEqual(60);
    }
  });

  it("garde entière une phrase plus longue que le plafond", () => {
    // Pas de fin de phrase à l'intérieur : il n'y a rien à couper, et couper au mot
    // ressemblerait à un bug d'affichage.
    const seule = `${"une proposition de plus, ".repeat(40)}et voilà la fin.`;

    expect(seule.length).toBeGreaterThan(SHEET_LIMITS.paragraphChars);
    expect(splitParagraph(seule)).toEqual([seule]);
  });

  it("ne prend pas le point d'une formule pour une fin de phrase", () => {
    const avecFormule = [
      "Le rendement de conversion se calcule à partir de la mesure de puissance électrique.",
      `On pose $\\eta = 0.92$ Pour une installation nominale, et la valeur chute en régime modulé.`,
      "Les pertes thermiques expliquent l'essentiel de cet écart entre les deux régimes.",
      "Une installation bien dimensionnée récupère une part de cette chaleur en aval du cycle.",
      "Le gain net dépend alors de la température de la source froide disponible sur le site.",
      "Les exploitants retiennent en pratique une fourchette de quatre-vingts à quatre-vingt-dix.",
    ].join(" ");

    for (const part of splitParagraph(avecFormule)) {
      // Une coupure dans `$…$` laisserait un dollar orphelin d'un côté et un de l'autre.
      expect((part.match(/\$/g)?.length ?? 0) % 2).toBe(0);
    }
  });

  it("ne coupe pas entre deux marqueurs de gras", () => {
    const avecGras = [
      "La réplication de l'ADN se déroule en trois temps portés par des enzymes distinctes.",
      "**L'hélicase ouvre la double hélice. La primase pose ensuite une amorce d'ARN complémentaire.**",
      "L'ADN polymérase allonge enfin le brin naissant dans le sens cinq prime vers trois prime.",
      "Chaque brin parental sert de matrice, ce qui rend la réplication semi-conservative.",
      "Les fragments d'Okazaki se forment sur le brin retardé puis sont soudés par la ligase.",
      "Une erreur d'appariement est corrigée par la relecture de la polymérase elle-même.",
    ].join(" ");

    for (const part of splitParagraph(avecGras)) {
      expect((part.match(/\*\*/g)?.length ?? 0) % 2).toBe(0);
    }
  });

  it("ne prend pas une initiale pour une fin de phrase", () => {
    const avecInitiale = [
      "Le modèle de la double hélice est publié dans la revue Nature au printemps de 1953.",
      "J. Watson et F. Crick s'appuient sur les clichés de diffraction de Rosalind Franklin.",
      "La structure explique d'un coup la réplication fidèle et la nature du code génétique.",
      "Elle vaut à ses auteurs le prix Nobel de physiologie ou médecine quelques années plus tard.",
      "Franklin, morte en 1958, n'a pas pu figurer parmi les lauréats de cette distinction.",
      "Son rôle a longtemps été minoré dans les récits que la discipline a faits d'elle-même.",
    ].join(" ");

    for (const part of splitParagraph(avecInitiale)) {
      expect(part).not.toMatch(/\bJ\.$/);
      expect(part).not.toMatch(/\bF\.$/);
    }
  });
});

describe("la fiche normalisée", () => {
  it("rend deux blocs là où le modèle en a écrit un trop long", () => {
    const blocks = normalizeSheet({ blocks: [{ type: "paragraph", text: PAVE }] });

    expect(blocks.length).toBeGreaterThan(1);
    expect(blocks.every((block) => block.type === "paragraph")).toBe(true);
  });
});

/**
 * **La cicatrice des fiches déjà écrites.**
 *
 * `\rightarrow` mal échappé est une échappée JSON *valide* : `JSON.parse` réussissait et
 * rendait un retour chariot suivi de « ightarrow ». Les fiches de cette époque sont en base,
 * et personne ne va les réécrire.
 */
describe("restoreLatexCommands", () => {
  it("rend sa flèche à une équation enregistrée de travers", () => {
    expect(restoreLatexCommands("2H_2O\rightarrow 4H^+")).toBe("2H_2O\\rightarrow 4H^+");
  });

  it("rend les cinq échappées d'une seule lettre", () => {
    expect(restoreLatexCommands("\frac{a}{b}")).toBe("\\frac{a}{b}");
    expect(restoreLatexCommands("\times")).toBe("\\times");
    expect(restoreLatexCommands("\beta")).toBe("\\beta");
    expect(restoreLatexCommands("\nabla")).toBe("\\nabla");
    expect(restoreLatexCommands("\bH")).toBe("\\bH");
  });

  it("ne touche pas à une formule saine", () => {
    const saine = "6 CO_2 + 12 H_2O \\rightarrow C_6H_{12}O_6 + 6 O_2";
    expect(restoreLatexCommands(saine)).toBe(saine);
  });

  it("laisse un caractère de contrôle qui ne précède pas une lettre", () => {
    // Il ne commence alors aucune commande : le restituer inventerait un antislash.
    expect(restoreLatexCommands("a\n 2")).toBe("a\n 2");
    expect(restoreLatexCommands("a\n")).toBe("a\n");
  });

  it("répare la formule au moment de normaliser la fiche", () => {
    const blocks = normalizeSheet({
      blocks: [{ type: "formula", latex: "2H_2O\rightarrow 4H^+ + 4e^- + O_2" }],
    });

    expect(blocks).toHaveLength(1);
    expect(blocks[0]).toMatchObject({ type: "formula", latex: "2H_2O\\rightarrow 4H^+ + 4e^- + O_2" });
  });
});

/**
 * Le plafond vit dans trois fichiers, et un plafond appliqué d'un seul côté donne deux
 * découpages pour une seule fiche. Le Swift ne s'exécute pas d'ici : on lit sa constante.
 */
describe("le plafond du paragraphe, des deux côtés", () => {
  const swift = readFileSync(
    resolve(dirname(fileURLToPath(import.meta.url)), "../../../..", "Micabo/Models/CourseSheet.swift"),
    "utf8",
  );

  it("vaut la même chose sur l'iPhone", () => {
    expect(SHEET_LIMITS.paragraphChars).toBe(320);
    expect(swift).toContain(`static let paragraphChars = ${SHEET_LIMITS.paragraphChars}`);
  });

  it("y est appliqué par le même découpage", () => {
    expect(swift).toContain("SheetText.split(text).map { .paragraph(text: $0) }");
  });

  it("rend aussi son antislash à une commande LaTeX enregistrée", () => {
    expect(swift).toContain("static func restoringLatexCommands");
    expect(swift).toContain("SheetText.restoringLatexCommands(trimmed)");
  });
});
