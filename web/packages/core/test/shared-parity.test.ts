/**
 * **Les catalogues partagés ne divergent pas.**
 *
 * `src/lesson/icons.ts` et `src/lesson/symbols.ts` sont des copies de
 * `supabase/functions/_shared/`. Une copie non surveillée dérive : le serveur apprend une
 * icône, le site l'ignore et affiche un livre à la place. Ici chaque copie est comparée à
 * l'octet près à son original.
 *
 * Si ce test tombe, il n'y a rien à débattre :
 *   pnpm --filter @micabo/core sync:shared
 */

import { readFileSync } from "node:fs";

import { describe, expect, it } from "vitest";

import { SHARED_COPIES, expectedCopy } from "../scripts/sync-shared";
import { DEFAULT_ICON, LESSON_ICONS, normalizeIcon } from "../src/lesson/icons";
import {
  DEFAULT_SYMBOL,
  PATH_SYMBOLS,
  normalizeSymbol,
  uniqueSymbols,
} from "../src/lesson/symbols";

describe("les copies des catalogues partagés", () => {
  for (const copy of SHARED_COPIES) {
    it(`${copy.name} : identique à l'original du serveur`, () => {
      expect(readFileSync(copy.target, "utf8")).toBe(expectedCopy(copy));
    });
  }
});

describe("les icônes 3D", () => {
  it("ramènent un nom inconnu au livre", () => {
    expect(normalizeIcon("globe")).toBe("globe");
    expect(normalizeIcon("Globe ")).toBe("globe");
    expect(normalizeIcon("licorne")).toBe(DEFAULT_ICON);
    expect(normalizeIcon(undefined)).toBe(DEFAULT_ICON);
  });

  it("ont chacune un sens, et un seul identifiant", () => {
    const ids = LESSON_ICONS.map((icon) => icon.id);
    expect(new Set(ids).size).toBe(ids.length);
    for (const icon of LESSON_ICONS) expect(icon.meaning.length).toBeGreaterThan(3);
  });
});

describe("les pictogrammes du chemin", () => {
  it("ne gardent qu'un nom du catalogue, et l'ampoule reste le repli", () => {
    expect(normalizeSymbol("atom")).toBe("atom");
    expect(normalizeSymbol("licorne")).toBe("");
    expect(PATH_SYMBOLS[0]?.id).toBe(DEFAULT_SYMBOL);
  });

  it("ne se répètent jamais dans une leçon", () => {
    const ids = PATH_SYMBOLS.map((symbol) => symbol.id);
    expect(new Set(ids).size).toBe(ids.length);
    const picked = uniqueSymbols(["atom", "atom", "", "leaf", "atom"]);
    expect(new Set(picked).size).toBe(picked.length);
    expect(picked).toHaveLength(5);
  });
});
