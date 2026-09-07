import { ALL_SUBJECTS, SUBJECT_FAMILIES } from "@micabo/core";
import { describe, expect, it } from "vitest";

import { SITE_PAGES } from "../site-pages";

import { CATALOGS, catalogFor, en, fr } from "./catalogs";
import { formatMessage, lookup, type MessageTree } from "./format";
import {
  DEFAULT_UI_LOCALE,
  UI_LOCALE_META,
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
  it("accepte en, fr, de, es, tr — l'anglais est la base", () => {
    expect(UI_LOCALES).toEqual(["en", "fr", "de", "es", "tr"]);
    expect(DEFAULT_UI_LOCALE).toBe("en");
    expect(isUiLocale("en")).toBe(true);
    expect(isUiLocale("fr")).toBe(true);
    expect(isUiLocale("de")).toBe(true);
    expect(isUiLocale("it")).toBe(false);
  });

  it("sert un catalogue distinct par langue", () => {
    expect(catalogFor("en")).not.toBe(catalogFor("fr"));
    expect(catalogFor("fr")).not.toBe(catalogFor("de"));
    expect(catalogFor("es")).not.toBe(catalogFor("tr"));
    expect(lookup(catalogFor("en") as unknown as MessageTree, "onboarding.welcomeTitle")).toMatch(
      /Welcome/,
    );
    expect(lookup(catalogFor("fr") as unknown as MessageTree, "onboarding.welcomeTitle")).toMatch(
      /Bienvenue/,
    );
    expect(lookup(catalogFor("de") as unknown as MessageTree, "onboarding.welcomeTitle")).toMatch(
      /Willkommen/,
    );
  });

  it("associe un drapeau à chaque langue", () => {
    expect(UI_LOCALE_META.en.flag).toBe("🇬🇧");
    expect(UI_LOCALE_META.fr.flag).toBe("🇫🇷");
    expect(UI_LOCALE_META.de.flag).toBe("🇩🇪");
    expect(UI_LOCALE_META.es.flag).toBe("🇪🇸");
    expect(UI_LOCALE_META.tr.flag).toBe("🇹🇷");
    for (const locale of UI_LOCALES) {
      expect(UI_LOCALE_META[locale].flag.length).toBeGreaterThan(0);
      expect(UI_LOCALE_META[locale].native.length).toBeGreaterThan(0);
    }
  });

  it("lit Accept-Language, sinon l'anglais", () => {
    expect(localeFromAcceptLanguage("de-DE,de;q=0.9,en;q=0.8")).toBe("de");
    expect(localeFromAcceptLanguage("es-MX,es;q=0.8")).toBe("es");
    expect(localeFromAcceptLanguage("tr")).toBe("tr");
    expect(localeFromAcceptLanguage("fr-CA,fr;q=0.9")).toBe("fr");
    expect(localeFromAcceptLanguage("en-US,en;q=0.9")).toBe("en");
    expect(localeFromAcceptLanguage(null)).toBe("en");
    expect(localeFromAcceptLanguage("it-IT,it;q=0.9")).toBe(DEFAULT_UI_LOCALE);
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

  it("a les mêmes clés en anglais, allemand, espagnol et turc", () => {
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
      expect(lookup(CATALOGS[locale] as unknown as MessageTree, "demo.legendWith")).toBeTruthy();
      expect(lookup(CATALOGS[locale] as unknown as MessageTree, "app.paywall.yearly")).toBeTruthy();
      expect(lookup(CATALOGS[locale] as unknown as MessageTree, "locale.choose")).toBeTruthy();
      expect(lookup(CATALOGS[locale] as unknown as MessageTree, "locale.en")).toBe("English");
    }
  });

  it("traduit les pages de droit", () => {
    const tEn = makeTranslator("en", CATALOGS.en as unknown as MessageTree, fr as unknown as MessageTree);
    const tTr = makeTranslator("tr", CATALOGS.tr as unknown as MessageTree, fr as unknown as MessageTree);
    const tDe = makeTranslator("de", CATALOGS.de as unknown as MessageTree, fr as unknown as MessageTree);
    const tEs = makeTranslator("es", CATALOGS.es as unknown as MessageTree, fr as unknown as MessageTree);
    expect(tEn("legal.privacy.heading")).toBe("Privacy policy");
    expect(tEn("legal.terms.heading")).toBe("Terms of use");
    expect(tTr("legal.privacy.heading")).toBe("Gizlilik politikası");
    expect(tTr("legal.terms.heading")).toBe("Kullanım koşulları");
    expect(tDe("legal.privacy.heading")).toBe("Datenschutzrichtlinie");
    expect(tEs("legal.terms.heading")).toBe("Condiciones de uso");
    expect(tTr("legal.privacy.heading")).not.toMatch(/Politique|Confidentialité/);
    expect(tDe("legal.terms.lawBody")).toMatch(/französischen|französischem/);
    expect(lookup(CATALOGS.fr as unknown as MessageTree, "legal.privacy.intro1")).toContain("[[site]]");
    expect(lookup(CATALOGS.en as unknown as MessageTree, "legal.privacy.intro1")).toContain("[[site]]");
    expect(lookup(CATALOGS.tr as unknown as MessageTree, "legal.privacy.intro1")).toContain("[[site]]");
  });

  it("ne laisse plus le chrome signalé en français hors fr", () => {
    const leftovers = [
      "app.brand.tagline",
      "demo.card1Kind",
      "demo.card1Front",
      "demo.card1Back",
      "demo.card1Note",
      "app.course.visibility.label",
      "app.course.lockedTitle",
      "app.workshop.emptyTitle",
      "app.workshop.emptyHint",
      "app.import.documentLanguage",
      "app.institution.university",
      "app.institution.lycee",
    ] as const;
    const french = leftovers.map((key) => lookup(fr as unknown as MessageTree, key));
    for (const locale of UI_LOCALES.filter((item) => item !== "fr")) {
      for (const [index, key] of leftovers.entries()) {
        const value = lookup(CATALOGS[locale] as unknown as MessageTree, key);
        expect(value, `${locale}:${key}`).not.toEqual(french[index]);
        expect(value, `${locale}:${key}`).not.toMatch(/étudier|Recto verso|océans|évapor|Qui peut|Aucune carte|Génère-les|suite de la fiche/i);
      }
    }
  });

  it("relie chaque page d'article à des clés de catalogue", () => {
    expect(SITE_PAGES.map((page) => page.id)).toEqual(["method", "exam", "anki"]);
    for (const page of SITE_PAGES) {
      expect(lookup(fr as unknown as MessageTree, `articles.${page.id}.metaTitle`)).toBeTruthy();
      expect(lookup(en as unknown as MessageTree, `articles.${page.id}.h1`)).toBeTruthy();
    }
  });

  it("traduit les trois articles, titres compris", () => {
    const leftovers = [
      "articles.method.h1",
      "articles.exam.h1",
      "articles.anki.h1",
      "articles.method.metaTitle",
      "articles.exam.metaTitle",
      "articles.anki.metaTitle",
      "articles.shared.ctaTitle",
    ] as const;
    const french = leftovers.map((key) => lookup(fr as unknown as MessageTree, key));
    for (const locale of UI_LOCALES.filter((item) => item !== "fr")) {
      for (const [index, key] of leftovers.entries()) {
        const value = lookup(CATALOGS[locale] as unknown as MessageTree, key);
        expect(value, `${locale}:${key}`).not.toEqual(french[index]);
        expect(value, `${locale}:${key}`).not.toMatch(
          /Relire ne suffit|Tu donnes la date|ce qui change vraiment|Dépose un cours/i,
        );
      }
    }
    const tEn = makeTranslator("en", CATALOGS.en as unknown as MessageTree, fr as unknown as MessageTree);
    const tTr = makeTranslator("tr", CATALOGS.tr as unknown as MessageTree, fr as unknown as MessageTree);
    expect(tEn("articles.method.h1")).toMatch(/Rereading|Remembering/);
    expect(tTr("articles.method.h1")).toMatch(/Hatırlamak/);
    expect(tTr("articles.anki.metaTitle")).toMatch(/Anki/);
  });

  it("traduit le paywall et le mode examen en turc", () => {
    const t = makeTranslator("tr", CATALOGS.tr as unknown as MessageTree, fr as unknown as MessageTree);
    expect(t("app.paywall.yearly")).toBe("Yıllık");
    expect(t("app.paywall.weekly")).toBe("Haftalık");
    expect(t("app.paywall.trialBadge", { days: 3 })).toBe("3 gün ücretsiz");
    expect(t("demo.axisExamDay")).toBe("sınav günü");
    expect(t("demo.cardsCovered")).not.toMatch(/cartes/);
    expect(t("demo.legendWith")).not.toMatch(/Avec Micabo/);
  });
});

describe("matières affichées", () => {
  it("couvre chaque famille et chaque matière du noyau", () => {
    const coverage = subjectDisplayCoverage();
    expect(coverage.families.sort()).toEqual([...SUBJECT_FAMILIES.map((family) => family.name)].sort());
    expect(coverage.subjects.sort()).toEqual([...ALL_SUBJECTS].sort());
  });
});
