import { describe, expect, it } from "vitest";

import { indexableAlternates } from "./i18n/alternates";
import { TRANSLATED_UI_LOCALES, isTranslatedLocale } from "./i18n/catalogs";
import { UI_LOCALES, UI_LOCALE_META } from "./i18n/locales";
import { INDEXABLE_PATHS, localizedPath } from "./i18n/paths";
import { indexableSitemap, searchConsoleUrls } from "./i18n/sitemap";

function absolute(href: string): string {
  return href === "/" ? "https://www.micabo.app/" : `https://www.micabo.app${href}`;
}

describe("sitemap", () => {
  it("émet chaque page indexable dans chaque langue traduite", () => {
    const entries = indexableSitemap();
    expect(TRANSLATED_UI_LOCALES.length).toBeGreaterThanOrEqual(5);
    expect(entries).toHaveLength(INDEXABLE_PATHS.length * TRANSLATED_UI_LOCALES.length);
    const urls = entries.map((entry) => entry.url);
    expect(urls).toContain("https://www.micabo.app/");
    expect(urls).toContain("https://www.micabo.app/fr");
    expect(urls).toContain("https://www.micabo.app/tr");
    expect(urls).toContain("https://www.micabo.app/fr/methode");
    expect(urls).toContain("https://www.micabo.app/tr/methode");
    expect(urls).toContain("https://www.micabo.app/de/mode-examen");
    expect(urls).toContain("https://www.micabo.app/es/micabo-ou-anki");
    expect(urls.some((url) => url.includes("/app"))).toBe(false);
    expect(urls.some((url) => url.includes("/commencer"))).toBe(false);
    expect(urls.some((url) => /\/en(\/|$)/.test(url.replace("https://www.micabo.app", "")))).toBe(
      false,
    );
  });

  it("tient hors du sitemap une langue qui n'est encore que l'anglais", () => {
    const urls = indexableSitemap().map((entry) => entry.url);
    for (const locale of UI_LOCALES) {
      const url = absolute(localizedPath(locale, "/methode"));
      expect(urls.includes(url), locale).toBe(isTranslatedLocale(locale));
    }
  });

  it("liste les URL que Search Console doit lire, sans /en ni l'app", () => {
    expect(searchConsoleUrls()).toEqual(
      INDEXABLE_PATHS.flatMap((path) =>
        TRANSLATED_UI_LOCALES.map((locale) => absolute(localizedPath(locale, path))),
      ),
    );
    const urls = searchConsoleUrls();
    for (const url of [
      "https://www.micabo.app/",
      "https://www.micabo.app/fr",
      "https://www.micabo.app/de",
      "https://www.micabo.app/es",
      "https://www.micabo.app/tr",
      "https://www.micabo.app/methode",
      "https://www.micabo.app/fr/methode",
      "https://www.micabo.app/de/methode",
      "https://www.micabo.app/es/methode",
      "https://www.micabo.app/tr/methode",
      "https://www.micabo.app/mode-examen",
      "https://www.micabo.app/fr/mode-examen",
      "https://www.micabo.app/de/mode-examen",
      "https://www.micabo.app/es/mode-examen",
      "https://www.micabo.app/tr/mode-examen",
      "https://www.micabo.app/micabo-ou-anki",
      "https://www.micabo.app/fr/micabo-ou-anki",
      "https://www.micabo.app/de/micabo-ou-anki",
      "https://www.micabo.app/es/micabo-ou-anki",
      "https://www.micabo.app/tr/micabo-ou-anki",
      "https://www.micabo.app/confidentialite",
      "https://www.micabo.app/fr/confidentialite",
      "https://www.micabo.app/de/confidentialite",
      "https://www.micabo.app/es/confidentialite",
      "https://www.micabo.app/tr/confidentialite",
      "https://www.micabo.app/conditions",
      "https://www.micabo.app/fr/conditions",
      "https://www.micabo.app/de/conditions",
      "https://www.micabo.app/es/conditions",
      "https://www.micabo.app/tr/conditions",
    ]) {
      expect(urls).toContain(url);
    }
    for (const path of INDEXABLE_PATHS) {
      for (const locale of TRANSLATED_UI_LOCALES) {
        const href = localizedPath(locale, path);
        const url = href === "/" ? "https://www.micabo.app/" : `https://www.micabo.app${href}`;
        expect(searchConsoleUrls()).toContain(url);
      }
    }
  });

  it("pose le même jeu hreflang sur chaque ligne", () => {
    for (const entry of indexableSitemap()) {
      const languages = entry.alternates.languages;
      expect(languages.en).toBeTruthy();
      expect(languages.fr).toBeTruthy();
      expect(languages.tr).toBeTruthy();
      expect(languages["x-default"]).toBe(languages.en);
      expect(Object.keys(languages).sort()).toEqual(
        [...TRANSLATED_UI_LOCALES.map((locale) => UI_LOCALE_META[locale].hreflang), "x-default"].sort(),
      );
    }
  });

  it("pose dans le HTML le même jeu hreflang que dans le sitemap", () => {
    for (const path of INDEXABLE_PATHS) {
      const fromSitemap = indexableSitemap().find((entry) => entry.url === absolute(localizedPath("en", path)));
      for (const locale of UI_LOCALES) {
        const alternates = indexableAlternates(locale, path);
        expect(alternates.languages, `${locale} ${path}`).toEqual(fromSitemap?.alternates.languages);
        // Une langue sans traduction sert l'anglais sous son préfixe : elle canonise vers lui.
        expect(alternates.canonical, `${locale} ${path}`).toBe(
          localizedPath(isTranslatedLocale(locale) ? locale : "en", path),
        );
      }
    }
  });

  // Une seule date, écrite en dur pour les trente adresses, est ce que Google finit par
  // ignorer : c'est ce qu'il y avait ici, et c'est ce qui laisse une page « détectée,
  // actuellement non indexée » sans moyen de rappeler le robot. Une date par page, la vraie.
  it("date chaque page pour elle-même, et pas toutes pareil", () => {
    const entries = indexableSitemap();
    for (const entry of entries) {
      expect(entry.lastModified).toBeInstanceOf(Date);
      expect(Number.isNaN(entry.lastModified.getTime())).toBe(false);
    }

    const distinct = new Set(entries.map((entry) => entry.lastModified.toISOString()));
    expect(distinct.size).toBeGreaterThan(1);

    // Les langues d'une page changent dans le même commit : elles partagent sa date.
    const byPath = (suffix: string) =>
      entries.filter((entry) => entry.url.endsWith(suffix)).map((e) => e.lastModified.getTime());
    const method = byPath("/methode");
    expect(method).toHaveLength(TRANSLATED_UI_LOCALES.length);
    expect(new Set(method).size).toBe(1);

    // Et une page n'emprunte pas la date d'une autre : la méthode et l'accueil ont bougé
    // des jours différents.
    const home = entries.find((entry) => entry.url === "https://www.micabo.app/");
    expect(home?.lastModified.getTime()).not.toBe(method[0]);
  });
});
