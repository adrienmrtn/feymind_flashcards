/**
 * **Les pages publiques, nommées une fois.**
 *
 * Un seul fichier les décrit, et il sert au sitemap, au pied de page, à la barre
 * des pages de contenu et aux liens croisés. Les textes — titre, extrait, corps —
 * vivent dans les catalogues (`articles.*`). Ici ne reste que l'adresse et le
 * poids relatif : une page ajoutée ici apparaît partout.
 *
 * `id` relie la page à `articles.method` / `exam` / `anki` et à `site.method` etc.
 */

import type { Route } from "next";

export type SitePageId = "method" | "exam" | "anki";

export interface SitePage {
  id: SitePageId;
  path: Route;
  /** Poids relatif dans le sitemap, entre nos pages et elles seules. */
  priority: number;
}

export const METHOD_PAGE: SitePage = {
  id: "method",
  path: "/methode" as Route,
  priority: 0.8,
};

export const EXAM_PAGE: SitePage = {
  id: "exam",
  path: "/mode-examen" as Route,
  priority: 0.8,
};

export const ANKI_PAGE: SitePage = {
  id: "anki",
  path: "/micabo-ou-anki" as Route,
  priority: 0.7,
};

/** Dans l'ordre de lecture : la méthode explique le reste. */
export const SITE_PAGES: readonly SitePage[] = [METHOD_PAGE, EXAM_PAGE, ANKI_PAGE];

/** Les deux autres pages, pour le bloc « à lire ensuite » au pied d'une page. */
export function otherPages(current: SitePage): SitePage[] {
  return SITE_PAGES.filter((page) => page.path !== current.path);
}

export function siteNavKey(id: SitePageId): `site.${SitePageId}` {
  return `site.${id}`;
}

export function articleMetaTitleKey(id: SitePageId): `articles.${SitePageId}.metaTitle` {
  return `articles.${id}.metaTitle`;
}

export function articleMetaDescriptionKey(
  id: SitePageId,
): `articles.${SitePageId}.metaDescription` {
  return `articles.${id}.metaDescription`;
}
