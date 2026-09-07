import { CANONICAL_URL } from "../config";
import { SITE_PAGES } from "../site-pages";
import { UI_LOCALES } from "./locales";
import { INDEXABLE_PATHS, languageAlternatePaths, localizedPath } from "./paths";

export type SitemapEntry = {
  url: string;
  lastModified: Date;
  changeFrequency: "weekly" | "monthly" | "yearly";
  priority: number;
  alternates: { languages: Record<string, string> };
};

function absolute(path: string): string {
  return path === "/" ? `${CANONICAL_URL}/` : `${CANONICAL_URL}${path}`;
}

/**
 * Les pages publiques, **dans les quatre langues**.
 *
 * Chaque URL a son jeu `hreflang`, le même que dans le HTML.
 */
export function indexableSitemap(updated = new Date("2026-09-07")): SitemapEntry[] {
  const priorityOf = (path: string): number => {
    if (path === "/") return 1;
    const page = SITE_PAGES.find((item) => item.path === path);
    return page?.priority ?? 0.3;
  };
  const frequency = (path: string): "weekly" | "monthly" | "yearly" => {
    if (path === "/") return "weekly";
    if (path === "/confidentialite" || path === "/conditions") return "yearly";
    return "monthly";
  };

  return INDEXABLE_PATHS.flatMap((path) => {
    const languages = languageAlternatePaths(path);
    const alternates = {
      languages: {
        fr: absolute(languages.fr),
        de: absolute(languages.de),
        es: absolute(languages.es),
        tr: absolute(languages.tr),
        "x-default": absolute(languages.fr),
      },
    };
    return UI_LOCALES.map((locale) => {
      const href = localizedPath(locale, path);
      return {
        url: absolute(href),
        lastModified: updated,
        changeFrequency: frequency(path),
        priority: priorityOf(path),
        alternates,
      };
    });
  });
}

/** Les 24 adresses à coller dans Search Console, dans le même ordre que le sitemap. */
export function searchConsoleUrls(): string[] {
  return indexableSitemap().map((entry) => entry.url);
}
