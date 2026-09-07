import { describe, expect, it } from "vitest";

import { INDEXABLE_PATHS } from "./i18n/paths";
import { indexableSitemap } from "./i18n/sitemap";

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

  it("pose le même jeu hreflang sur chaque ligne", () => {
    for (const entry of indexableSitemap()) {
      const languages = entry.alternates.languages;
      expect(languages.fr).toBeTruthy();
      expect(languages.tr).toBeTruthy();
      expect(languages["x-default"]).toBe(languages.fr);
    }
  });
});
