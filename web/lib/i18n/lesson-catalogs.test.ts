import { readFileSync } from "node:fs";

import { describe, expect, it } from "vitest";

import { LOCALES, SOURCE, moduleFor, parseTable, targetFor, toTree } from "../../scripts/sync-lesson-catalogs.mjs";

import { CATALOGS } from "./catalogs";
import { formatMessage, lookup, type MessageTree } from "./format";

/**
 * **Les phrases de la leçon sont celles de l'app.**
 *
 * `lesson-<langue>.ts` est une copie de `LessonI18nCatalogs.swift`. Si ce test tombe :
 * `node web/scripts/sync-lesson-catalogs.mjs`.
 */
describe("les catalogues de la leçon", () => {
  const swift = readFileSync(SOURCE, "utf8");

  it("sont la copie du Swift, langue par langue", () => {
    for (const locale of LOCALES) {
      expect(readFileSync(targetFor(locale), "utf8"), locale).toBe(moduleFor(locale, swift));
    }
  });

  it("ont les mêmes clés dans les cinq langues, et le site les sert sous `lesson`", () => {
    const reference = [...parseTable(swift, "fr").keys()].sort();
    expect(reference.length).toBeGreaterThan(200);
    for (const locale of LOCALES) {
      expect([...parseTable(swift, locale).keys()].sort(), locale).toEqual(reference);
      const catalog = CATALOGS[locale as keyof typeof CATALOGS] as unknown as MessageTree;
      for (const key of reference) {
        expect(lookup(catalog, key), `${locale} ${key}`).toBeTypeOf("string");
      }
    }
  });

  it("gardent les jetons et les pluriels que le site sait formater", () => {
    const fr = CATALOGS.fr as unknown as MessageTree;
    expect(lookup(fr, "lesson.tab.lessons")).toBe("Leçons");
    expect(formatMessage(lookup(fr, "lesson.path.step")!, { n: 4 })).toBe("Étape 4");
    expect(formatMessage(lookup(fr, "lesson.lessons.count")!, { count: 1 }, "fr")).toBe("1 leçon");
    expect(formatMessage(lookup(fr, "lesson.lessons.count")!, { count: 3 }, "fr")).toBe("3 leçons");
  });

  it("ne mélangent pas phrase et groupe sous une même clé", () => {
    expect(() => toTree(new Map([["lesson.a", "x"], ["lesson.a.b", "y"]]))).toThrow();
  });
});
