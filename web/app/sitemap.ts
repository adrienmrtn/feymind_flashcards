import type { MetadataRoute } from "next";

import { indexableSitemap } from "@/lib/i18n/sitemap";

/**
 * Les pages publiques, **dans les quatre langues**.
 *
 * Chaque URL a son jeu `hreflang` dans le sitemap, le même que dans le HTML.
 * Les deux doivent dire la même chose.
 */
export default function sitemap(): MetadataRoute.Sitemap {
  return indexableSitemap();
}
