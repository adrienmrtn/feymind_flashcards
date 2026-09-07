import { describe, expect, it } from "vitest";

import { UI_LOCALES } from "./i18n/locales";
import { INDEXABLE_PATHS, localizedPath } from "./i18n/paths";
import { indexableSitemap, searchConsoleUrls } from "./i18n/sitemap";

describe("sitemap", () => {
  it("émet chaque page indexable dans les quatre langues", () => {
    const entries = indexableSitemap();
    expect(entries).toHaveLength(INDEXABLE_PATHS.length * 4);
    const urls = entries.map((entry) => entry.url);
    expect(urls).toContain("https://www.micabo.app/");
    expect(urls).toContain("https://www.micabo.app/tr");
    expect(urls).toContain("https://www.micabo.app/tr/methode");
    expect(urls).toContain("https://www.micabo.app/de/mode-examen");
    expect(urls).toContain("https://www.micabo.app/es/micabo-ou-anki");
    expect(urls.some((url) => url.includes("/app"))).toBe(false);
    expect(urls.some((url) => url.includes("/commencer"))).toBe(false);
    expect(urls.some((url) => url.includes("/fr/"))).toBe(false);
  });

  it("liste les 24 URL que Search Console doit lire, sans /fr ni l'app", () => {
    expect(searchConsoleUrls()).toEqual([
      "https://www.micabo.app/",
      "https://www.micabo.app/de",
      "https://www.micabo.app/es",
      "https://www.micabo.app/tr",
      "https://www.micabo.app/methode",
      "https://www.micabo.app/de/methode",
      "https://www.micabo.app/es/methode",
      "https://www.micabo.app/tr/methode",
      "https://www.micabo.app/mode-examen",
      "https://www.micabo.app/de/mode-examen",
      "https://www.micabo.app/es/mode-examen",
      "https://www.micabo.app/tr/mode-examen",
      "https://www.micabo.app/micabo-ou-anki",
      "https://www.micabo.app/de/micabo-ou-anki",
      "https://www.micabo.app/es/micabo-ou-anki",
      "https://www.micabo.app/tr/micabo-ou-anki",
      "https://www.micabo.app/confidentialite",
      "https://www.micabo.app/de/confidentialite",
      "https://www.micabo.app/es/confidentialite",
      "https://www.micabo.app/tr/confidentialite",
      "https://www.micabo.app/conditions",
      "https://www.micabo.app/de/conditions",
      "https://www.micabo.app/es/conditions",
      "https://www.micabo.app/tr/conditions",
    ]);
    for (const path of INDEXABLE_PATHS) {
      for (const locale of UI_LOCALES) {
        const href = localizedPath(locale, path);
        const url = href === "/" ? "https://www.micabo.app/" : `https://www.micabo.app${href}`;
        expect(searchConsoleUrls()).toContain(url);
      }
    }
  });

  it("pose le même jeu hreflang sur chaque ligne", () => {
    for (const entry of indexableSitemap()) {
      const languages = entry.alternates.languages;
      expect(languages.fr).toBeTruthy();
      expect(languages.tr).toBeTruthy();
      expect(languages["x-default"]).toBe(languages.fr);
    }
  });
});
