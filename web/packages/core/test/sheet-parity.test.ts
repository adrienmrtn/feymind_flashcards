/**
 * **Le test qui empêche les deux copies de diverger.**
 *
 * `src/sheet/canonical.ts` est une copie de `supabase/functions/_shared/sheet.ts`. Une copie
 * non surveillée dérive : quelqu'un ajuste un plafond côté serveur, le site continue d'en
 * appliquer un autre, et la même fiche se lit différemment selon l'appareil. Ici la copie est
 * comparée **à l'octet près** à son original.
 *
 * Si ce test tombe, il n'y a rien à débattre :
 *   pnpm --filter @micabo/core sync:sheet
 */

import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

import { HEADER, SOURCE, TARGET, canonicalBody } from "../scripts/sync-sheet";
import { SHEET_LIMITS, normalizeSheet, sheetToPlainText } from "../src/sheet/canonical";

describe("la copie du module de fiche", () => {
  it("est identique à l'original du serveur", () => {
    const copy = readFileSync(TARGET, "utf8");
    const expected = HEADER + canonicalBody(readFileSync(SOURCE, "utf8"));

    expect(copy).toBe(expected);
  });

  it("n'a qu'une seule différence d'import avec l'original", () => {
    const copy = readFileSync(TARGET, "utf8");

    expect(copy).toContain('import { stripEmDashes } from "./em-dashes";');
    // L'original importe depuis `fal.ts`, qui lit `Deno.env` et n'a rien à faire côté site.
    expect(copy).not.toContain('from "./fal.ts"');
  });
});

describe("les plafonds tiennent", () => {
  it("porte les valeurs que l'app applique aussi", () => {
    // Recopiées depuis `SheetLimits` dans `Micabo/Models/CourseSheet.swift`. Un plafond réglé
    // sous ce que le prompt exige efface exactement ce qu'on vient de demander.
    expect(SHEET_LIMITS.blocks).toBe(90);
    expect(SHEET_LIMITS.listItems).toBe(10);
    expect(SHEET_LIMITS.highlights).toBe(24);
  });
});

describe("la normalisation", () => {
  it("garde un paragraphe et jette un bloc inconnu", () => {
    const blocks = normalizeSheet({
      blocks: [
        { type: "paragraph", text: "Le cycle de l'eau décrit les échanges entre les réservoirs." },
        { type: "carousel", text: "Un type que l'application ne sait pas afficher." },
      ],
    });

    expect(blocks).toHaveLength(1);
    expect(blocks[0]!.type).toBe("paragraph");
  });

  it("garde une liste, ordonnée ou non", () => {
    const blocks = normalizeSheet({
      blocks: [
        { type: "list", ordered: true, items: ["Évaporation", "Condensation", "Précipitations"] },
      ],
    });

    const list = blocks[0];
    expect(list?.type).toBe("list");
    expect(list?.type === "list" ? list.ordered : null).toBe(true);
    expect(list?.type === "list" ? list.items : []).toHaveLength(3);
  });

  it("convertit une définition en phrase, terme en gras", () => {
    const blocks = normalizeSheet({
      blocks: [{ type: "definition", term: "Évaporation", text: "Le passage à l'état gazeux." }],
    });

    expect(blocks[0]).toEqual({
      type: "paragraph",
      text: "**Évaporation** : Le passage à l'état gazeux.",
    });
  });

  it("convertit une suite d'étapes en liste numérotée", () => {
    const blocks = normalizeSheet({
      blocks: [
        { type: "steps", title: "Dans l'ordre", items: ["Évaporation", "Condensation"] },
      ],
    });

    expect(blocks[0]).toEqual({ type: "paragraph", text: "**Dans l'ordre**" });
    expect(blocks[1]).toEqual({
      type: "list",
      ordered: true,
      items: ["Évaporation", "Condensation"],
    });
  });

  it("convertit un tableau en lignes lisibles plutôt que de le jeter", () => {
    const blocks = normalizeSheet({
      blocks: [
        {
          type: "table",
          title: "Les réservoirs",
          headers: ["Réservoir", "Part"],
          rows: [["Océans", "97 %"], ["Glaciers", "2 %"]],
        },
      ],
    });

    const list = blocks.find((block) => block.type === "list");
    expect(list?.type === "list" ? list.items : []).toEqual([
      "**Réservoir** : Océans, **Part** : 97 %",
      "**Réservoir** : Glaciers, **Part** : 2 %",
    ]);
  });

  it("convertit un graphe en liste de valeurs", () => {
    const blocks = normalizeSheet({
      blocks: [
        {
          type: "chart",
          title: "Temps de résidence",
          unit: "ans",
          bars: [{ label: "Océans", value: 3000 }, { label: "Lacs", value: 10 }],
        },
      ],
    });

    const list = blocks.find((block) => block.type === "list");
    expect(list?.type === "list" ? list.items : []).toEqual([
      "**Océans** : 3000 ans",
      "**Lacs** : 10 ans",
    ]);
  });

  it("ne garde d'une figure que sa légende", () => {
    const blocks = normalizeSheet({
      blocks: [
        { type: "figure", caption: "Cycle de Krebs", page: 2, image: "data:image/jpeg;base64,AAAA" },
      ],
    });

    expect(blocks).toEqual([{ type: "paragraph", text: "Cycle de Krebs" }]);
  });

  it("laisse le nom d'une couleur de surligneur hors du texte à plat", () => {
    // Sinon le modèle reçoit « menthe|le cycle » et le nom de la couleur se révise avec le
    // cours, sur les cartes comme sur les examens blancs.
    const flat = sheetToPlainText([
      { type: "paragraph", text: "Retiens ==menthe|le cycle de l'eau== avant tout." },
    ]);

    expect(flat).toBe("Retiens le cycle de l'eau avant tout.");
  });

  it("met la fiche à plat, listes comprises", () => {
    const flat = sheetToPlainText([
      { type: "heading", level: 1, text: "Le cycle de l'eau" },
      { type: "list", ordered: true, items: ["Évaporation", "Condensation"] },
      { type: "list", ordered: false, items: ["Océans : 97 %"] },
    ]);

    expect(flat).toBe("Le cycle de l'eau\n1. Évaporation\n2. Condensation\nOcéans : 97 %");
  });
});
