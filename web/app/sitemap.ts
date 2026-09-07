import type { MetadataRoute } from "next";

import { CANONICAL_URL } from "@/lib/config";
import { UI_LOCALES } from "@/lib/i18n/locales";
import { INDEXABLE_PATHS, languageAlternatePaths, localizedPath } from "@/lib/i18n/paths";
import { SITE_PAGES } from "@/lib/site-pages";

/**
 * Les pages publiques, **dans les quatre langues**.
 *
 * Chaque URL a son jeu `hreflang` dans le sitemap, le même que dans le HTML.
 * Les deux doivent dire la même chose.
 */
export default function sitemap(): MetadataRoute.Sitemap {
  const updated = new Date("2026-09-07");
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
        fr: `${CANONICAL_URL}${languages.fr === "/" ? "/" : languages.fr}`,
        de: `${CANONICAL_URL}${languages.de}`,
        es: `${CANONICAL_URL}${languages.es}`,
        tr: `${CANONICAL_URL}${languages.tr}`,
        "x-default": `${CANONICAL_URL}${languages.fr === "/" ? "/" : languages.fr}`,
      },
    };
    return UI_LOCALES.map((locale) => {
      const href = localizedPath(locale, path);
      return {
        url: href === "/" ? `${CANONICAL_URL}/` : `${CANONICAL_URL}${href}`,
        lastModified: updated,
        changeFrequency: frequency(path),
        priority: priorityOf(path),
        alternates,
      };
    });
  });
}
