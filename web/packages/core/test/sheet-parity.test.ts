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
    expect(SHEET_LIMITS.blocks).toBe(60);
    expect(SHEET_LIMITS.stepsItems).toBe(7);
    expect(SHEET_LIMITS.tableColumns).toBe(4);
    expect(SHEET_LIMITS.tableRows).toBe(8);
    expect(SHEET_LIMITS.chartBars).toBe(6);
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

  it("jette un tableau à une seule colonne", () => {
    const blocks = normalizeSheet({
      blocks: [
        { type: "paragraph", text: "Une phrase assez longue pour passer le seuil de trente." },
        { type: "table", headers: ["Seul"], rows: [["a"], ["b"]] },
      ],
    });

    expect(blocks.some((block) => block.type === "table")).toBe(false);
  });

  it("met la fiche à plat, valeurs de tableau comprises", () => {
    const flat = sheetToPlainText([
      { type: "heading", level: 1, text: "Le cycle de l'eau" },
      {
        type: "table",
        headers: ["Phase", "Lieu"],
        rows: [["Photochimique", "thylakoïdes"]],
      },
    ]);

    // « thylakoïdes » seul ne se révise pas : le nom de la colonne part avec la valeur.
    expect(flat).toContain("Phase : Photochimique, Lieu : thylakoïdes");
  });
});
