import { ALL_SUBJECTS, SUBJECT_FAMILIES } from "@micabo/core";
import { describe, expect, it } from "vitest";

import { SITE_PAGES } from "../site-pages";

import { CATALOGS, TRANSLATED_UI_LOCALES, catalogFor, en, fr, isTranslatedLocale } from "./catalogs";
import { formatMessage, lookup, type MessageTree } from "./format";
import {
  DEFAULT_UI_LOCALE,
  UI_LOCALE_META,
  UI_LOCALES,
  isUiLocale,
  localeFromAcceptLanguage,
  localeFromUrlSegment,
  matchAcceptLanguage,
  urlSegment,
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
  it("parle les vingt-six langues des apps — l'anglais est la base", () => {
    expect(UI_LOCALES).toEqual([
      "en", "fr", "de", "es", "es-419", "it", "pt", "pt-BR", "nl", "pl", "ro", "sv", "da",
      "fi", "et", "cs", "sk", "hu", "hr", "sl", "sr", "bg", "el", "ru", "tr", "ar",
    ]);
    expect(new Set(UI_LOCALES).size).toBe(26);
    expect(DEFAULT_UI_LOCALE).toBe("en");
    expect(UI_LOCALES[0]).toBe(DEFAULT_UI_LOCALE);
    expect(isUiLocale("en")).toBe(true);
    expect(isUiLocale("fr")).toBe(true);
    expect(isUiLocale("it")).toBe(true);
    expect(isUiLocale("pt-BR")).toBe(true);
    expect(isUiLocale("es-419")).toBe(true);
    expect(isUiLocale("pt-br")).toBe(false);
    expect(isUiLocale("ja")).toBe(false);
    expect(isUiLocale(null)).toBe(false);
  });

  it("donne à chaque langue ses métadonnées et un catalogue", () => {
    const hreflangs = new Set<string>();
    const segments = new Set<string>();
    for (const locale of UI_LOCALES) {
      const meta = UI_LOCALE_META[locale];
      expect(meta, locale).toBeDefined();
      expect(meta.html.length, locale).toBeGreaterThan(1);
      expect(meta.native.length, locale).toBeGreaterThan(1);
      expect(meta.flag.length, locale).toBeGreaterThan(0);
      expect(meta.og, locale).toMatch(/^[a-z]{2}_[A-Z]{2}$/);
      expect(meta.dir, locale).toBe(locale === "ar" ? "rtl" : "ltr");
      // Une locale qu'`Intl` connaît vraiment, et pas un repli silencieux sur l'anglais.
      expect(Intl.getCanonicalLocales(meta.bcp47)[0], locale).toBe(meta.bcp47);
      expect(new Intl.NumberFormat(meta.bcp47).resolvedOptions().locale.split("-")[0], locale).toBe(
        locale.split("-")[0],
      );
      hreflangs.add(meta.hreflang);
      segments.add(urlSegment(locale));
      expect(localeFromUrlSegment(urlSegment(locale)), locale).toBe(locale);

      const catalog = CATALOGS[locale];
      expect(catalog, locale).toBeDefined();
      expect(catalogFor(locale), locale).toBe(catalog);
    }
    expect(hreflangs.size).toBe(UI_LOCALES.length);
    expect(segments.size).toBe(UI_LOCALES.length);
    expect(UI_LOCALE_META["pt-BR"].hreflang).toBe("pt-BR");
    expect(UI_LOCALE_META["es-419"].hreflang).toBe("es-419");
    expect(UI_LOCALE_META.sr.html).toBe("sr-Latn");
    expect(urlSegment("pt-BR")).toBe("pt-br");
    expect(localeFromUrlSegment("PT-BR")).toBe("pt-BR");
    expect(localeFromUrlSegment("app")).toBeNull();
  });

  it("sait quelles langues ont leur traduction, et l'anglais en fait toujours partie", () => {
    expect(isTranslatedLocale("en")).toBe(true);
    for (const locale of ["fr", "de", "es", "tr"] as const) {
      expect(isTranslatedLocale(locale), locale).toBe(true);
    }
    for (const locale of UI_LOCALES) {
      expect(isTranslatedLocale(locale), locale).toBe(locale === "en" || CATALOGS[locale] !== en);
    }
    expect(TRANSLATED_UI_LOCALES[0]).toBe("en");
    expect(TRANSLATED_UI_LOCALES).toEqual(UI_LOCALES.filter(isTranslatedLocale));
  });

  it("sert un catalogue distinct par langue", () => {
    expect(catalogFor("en")).not.toBe(catalogFor("fr"));
    expect(catalogFor("fr")).not.toBe(catalogFor("de"));
    expect(catalogFor("es")).not.toBe(catalogFor("tr"));
    expect(lookup(catalogFor("en") as unknown as MessageTree, "onboarding.stepBienvenue")).toMatch(
      /Welcome/,
    );
    expect(lookup(catalogFor("fr") as unknown as MessageTree, "onboarding.stepBienvenue")).toMatch(
      /Bienvenue/,
    );
    expect(lookup(catalogFor("de") as unknown as MessageTree, "onboarding.stepBienvenue")).toMatch(
      /Willkommen/,
    );
  });

  it("associe un drapeau à chaque langue", () => {
    expect(UI_LOCALE_META.en.flag).toBe("🇬🇧");
    expect(UI_LOCALE_META.fr.flag).toBe("🇫🇷");
    expect(UI_LOCALE_META.de.flag).toBe("🇩🇪");
    expect(UI_LOCALE_META.es.flag).toBe("🇪🇸");
    expect(UI_LOCALE_META.tr.flag).toBe("🇹🇷");
    expect(UI_LOCALE_META["es-419"].flag).toBe("🇲🇽");
    expect(UI_LOCALE_META["pt-BR"].flag).toBe("🇧🇷");
    expect(UI_LOCALE_META.ar.flag).toBe("🇦🇪");
    for (const locale of UI_LOCALES) {
      expect(UI_LOCALE_META[locale].flag.length).toBeGreaterThan(0);
      expect(UI_LOCALE_META[locale].native.length).toBeGreaterThan(0);
    }
  });

  it("lit Accept-Language, sinon l'anglais", () => {
    expect(localeFromAcceptLanguage("de-DE,de;q=0.9,en;q=0.8")).toBe("de");
    expect(localeFromAcceptLanguage("tr")).toBe("tr");
    expect(localeFromAcceptLanguage("fr-CA,fr;q=0.9")).toBe("fr");
    expect(localeFromAcceptLanguage("en-US,en;q=0.9")).toBe("en");
    expect(localeFromAcceptLanguage(null)).toBe("en");
    expect(localeFromAcceptLanguage("it-IT,it;q=0.9")).toBe("it");
    expect(localeFromAcceptLanguage("ja-JP,ja;q=0.9")).toBe(DEFAULT_UI_LOCALE);
    expect(matchAcceptLanguage("ja-JP,ja;q=0.9")).toBeNull();
    expect(matchAcceptLanguage("nb-NO,no;q=0.9")).toBeNull();
    // Une langue qu'on ne parle pas en tête n'empêche pas la suivante.
    expect(localeFromAcceptLanguage("ja-JP,pl;q=0.8")).toBe("pl");
  });

  it("distingue les variantes régionales : l'étiquette entière d'abord, la langue ensuite", () => {
    expect(matchAcceptLanguage("pt-BR,pt;q=0.9")).toBe("pt-BR");
    expect(matchAcceptLanguage("pt-br")).toBe("pt-BR");
    expect(matchAcceptLanguage("pt_BR")).toBe("pt-BR");
    expect(matchAcceptLanguage("pt-PT,pt;q=0.9")).toBe("pt");
    expect(matchAcceptLanguage("pt")).toBe("pt");
    expect(matchAcceptLanguage("pt-AO")).toBe("pt");
    expect(matchAcceptLanguage("es-419")).toBe("es-419");
    expect(matchAcceptLanguage("es-MX,es;q=0.8")).toBe("es-419");
    expect(matchAcceptLanguage("es-AR")).toBe("es-419");
    expect(matchAcceptLanguage("es-CO")).toBe("es-419");
    expect(matchAcceptLanguage("es-US")).toBe("es-419");
    expect(matchAcceptLanguage("es-ES")).toBe("es");
    expect(matchAcceptLanguage("es")).toBe("es");
    expect(matchAcceptLanguage("sr-Latn-RS")).toBe("sr");
    expect(matchAcceptLanguage("sr-Cyrl")).toBe("sr");
    expect(matchAcceptLanguage("sr")).toBe("sr");
    expect(matchAcceptLanguage("bs-BA")).toBe("hr");
    expect(matchAcceptLanguage("ar-SA,ar;q=0.9")).toBe("ar");
    expect(matchAcceptLanguage("el-GR")).toBe("el");
    expect(matchAcceptLanguage("*")).toBeNull();
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

  it("sait few / many, les valeurs exactes, et les jetons dans une branche", () => {
    const ru = "{count, plural, one {# карточка} few {# карточки} many {# карточек} other {# карточки}}";
    expect(formatMessage(ru, { count: 1 }, "ru-RU")).toBe("1 карточка");
    expect(formatMessage(ru, { count: 3 }, "ru-RU")).toBe("3 карточки");
    expect(formatMessage(ru, { count: 5 }, "ru-RU")).toBe("5 карточек");
    expect(formatMessage(ru, { count: 21 }, "ru-RU")).toBe("21 карточка");

    const pl = "{n, plural, one {# fiszka} few {# fiszki} other {# fiszek}}";
    // `many` absent : la catégorie retombe sur `other`.
    expect(formatMessage(pl, { n: 5 }, "pl-PL")).toBe("5 fiszek");
    expect(formatMessage(pl, { n: 2 }, "pl-PL")).toBe("2 fiszki");

    const ar = "{n, plural, zero {لا بطاقات} one {بطاقة} two {بطاقتان} few {# بطاقات} many {# بطاقة} other {# بطاقة}}";
    expect(formatMessage(ar, { n: 0 }, "ar-AE")).toBe("لا بطاقات");
    expect(formatMessage(ar, { n: 2 }, "ar-AE")).toBe("بطاقتان");

    expect(formatMessage("{n, plural, =0 {none} one {one} other {#}}", { n: 0 }, "en-US")).toBe("none");
    expect(
      formatMessage("{n, plural, one {# card for {name}} other {# cards for {name}}}!", { n: 2, name: "Ana" }, "en-US"),
    ).toBe("2 cards for Ana!");
    expect(formatMessage("{n, plural, one {#} other {#}}", { n: 1234 }, "de-DE")).toBe("1.234");
  });
});

describe("catalogues", () => {
  const frenchKeys = flattenKeys(fr as unknown as MessageTree);

  it("a les mêmes clés dans toutes les langues", () => {
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

  it("forme les pluriels avec la locale Intl de la langue, pas avec le code du cookie", () => {
    const tree = { n: "{n, plural, one {# carta} other {# cartas}}" } as MessageTree;
    expect(makeTranslator("pt-BR", tree, tree)("n", { n: 1000 })).toBe("1.000 cartas");
    expect(makeTranslator("es-419", tree, tree)("n", { n: 1 })).toBe("1 carta");
    expect(makeTranslator("sr", tree, tree)("n", { n: 2 })).toBe("2 cartas");
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
      expect(lookup(CATALOGS[locale] as unknown as MessageTree, "app.profileTab.info")).toBeTruthy();
      expect(lookup(CATALOGS[locale] as unknown as MessageTree, "app.tour.home.bar.title")).toBeTruthy();
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
      "demo.card1Kind",
      "demo.card1Front",
      "demo.card1Back",
      "demo.card1Note",
      "app.institution.university",
      "app.institution.lycee",
      "app.tour.home.bar.body",
      "app.profileTab.exportData",
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
