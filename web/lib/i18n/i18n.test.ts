import { ALL_SUBJECTS, SUBJECT_FAMILIES } from "@micabo/core";
import { describe, expect, it } from "vitest";

import { CATALOGS, fr } from "./catalogs";
import { formatMessage, lookup, type MessageTree } from "./format";
import {
  DEFAULT_UI_LOCALE,
  UI_LOCALES,
  isUiLocale,
  localeFromAcceptLanguage,
} from "./locales";
import { subjectDisplayCoverage } from "./subject-display";
import { makeTranslator } from "./translate";

function flattenKeys(tree: MessageTree, prefix = ""): string[] {
  const keys: string[] = [];
  for (const [key, value] of Object.entries(tree)) {
    const path = prefix ? `${prefix}.${key}` : key;
    if (typeof value === "string") keys.push(path);
    else keys.push(...flattenKeys(value, path));
  }
  return keys.sort();
}

describe("locales", () => {
  it("n'accepte que fr, de, es, tr", () => {
    expect(UI_LOCALES).toEqual(["fr", "de", "es", "tr"]);
    expect(isUiLocale("fr")).toBe(true);
    expect(isUiLocale("de")).toBe(true);
    expect(isUiLocale("it")).toBe(false);
    expect(isUiLocale("en")).toBe(false);
  });

  it("lit Accept-Language, sinon le français", () => {
    expect(localeFromAcceptLanguage("de-DE,de;q=0.9,en;q=0.8")).toBe("de");
    expect(localeFromAcceptLanguage("es-MX,es;q=0.8")).toBe("es");
    expect(localeFromAcceptLanguage("tr")).toBe("tr");
    expect(localeFromAcceptLanguage("fr-CA,fr;q=0.9")).toBe("fr");
    expect(localeFromAcceptLanguage("en-US,en;q=0.9")).toBe(DEFAULT_UI_LOCALE);
    expect(localeFromAcceptLanguage(null)).toBe("fr");
  });
});

describe("formatMessage", () => {
  it("remplace un jeton", () => {
    expect(formatMessage("Ouvre le lien envoyé à {email}", { email: "a@b.fr" })).toBe(
      "Ouvre le lien envoyé à a@b.fr",
    );
  });

  it("choisit one / other", () => {
    const template = "{count, plural, one {# matière} other {# matières}}";
    expect(formatMessage(template, { count: 1 }, "fr")).toBe("1 matière");
    expect(formatMessage(template, { count: 3 }, "fr")).toBe("3 matières");
    expect(formatMessage("{n, plural, one {1 Fach} other {# Fächer}}", { n: 1 }, "de")).toBe(
      "1 Fach",
    );
    expect(formatMessage("{n, plural, one {1 Fach} other {# Fächer}}", { n: 4 }, "de")).toBe(
      "4 Fächer",
    );
  });
});

describe("catalogues", () => {
  const frenchKeys = flattenKeys(fr as unknown as MessageTree);

  it("a les mêmes clés en allemand, espagnol et turc", () => {
    for (const locale of UI_LOCALES) {
      expect(flattenKeys(CATALOGS[locale] as unknown as MessageTree)).toEqual(frenchKeys);
    }
  });

  it("ne laisse aucune chaîne vide", () => {
    for (const locale of UI_LOCALES) {
      for (const key of frenchKeys) {
        const value = lookup(CATALOGS[locale] as unknown as MessageTree, key);
        expect(value, `${locale}:${key}`).toEqual(expect.any(String));
        expect((value ?? "").length, `${locale}:${key}`).toBeGreaterThan(0);
      }
    }
  });

  it("traduit sans concaténer le compteur de matières", () => {
    const t = makeTranslator("de", CATALOGS.de as unknown as MessageTree, fr as unknown as MessageTree);
    expect(t("onboarding.continueOne")).toContain("1");
    expect(t("onboarding.continueMany", { n: 3 })).toContain("3");
    expect(t("onboarding.continueMany", { n: 3 })).not.toContain("{n}");
  });

  it("couvre le lexique app et copy", () => {
    for (const locale of UI_LOCALES) {
      expect(lookup(CATALOGS[locale] as unknown as MessageTree, "copy.cards")).toContain("plural");
      expect(lookup(CATALOGS[locale] as unknown as MessageTree, "app.home.tasks.title")).toBeTruthy();
      expect(lookup(CATALOGS[locale] as unknown as MessageTree, "nav.feedback")).toBeTruthy();
    }
  });
});

describe("matières affichées", () => {
  it("couvre chaque famille et chaque matière du noyau", () => {
    const coverage = subjectDisplayCoverage();
    expect(coverage.families.sort()).toEqual([...SUBJECT_FAMILIES.map((family) => family.name)].sort());
    expect(coverage.subjects.sort()).toEqual([...ALL_SUBJECTS].sort());
  });
});
