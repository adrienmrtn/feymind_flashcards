import { CANONICAL_URL } from "../config";
import { SITE_PAGES } from "../site-pages";
import { UI_LOCALES } from "./locales";
import {
  INDEXABLE_PATHS,
  type IndexablePath,
  languageAlternatePaths,
  localizedPath,
} from "./paths";

export type SitemapEntry = {
  url: string;
  lastModified: Date;
  changeFrequency: "weekly" | "monthly" | "yearly";
  priority: number;
  alternates: { languages: Record<string, string> };
};

/**
 * **Le jour où le texte de chaque page a changé pour la dernière fois.**
 *
 * Il y avait ici une seule date, écrite en dur pour les trente adresses, et jamais retouchée.
 * C'est pire que pas de date du tout : `lastmod` est ce sur quoi Google s'appuie pour décider
 * quand repasser, et une date identique partout, qui ne bouge pas d'un déploiement à l'autre,
 * ne dit rien. Google annonce explicitement qu'il ignore le `lastmod` d'un sitemap dès qu'il
 * le juge peu fiable — et un sitemap dont le `lastmod` est ignoré perd le seul levier qu'il a
 * pour faire revenir le robot sur une page qu'il a laissée de côté.
 *
 * Une date par page, donc, et la vraie : celle du dernier commit qui a touché le texte rendu.
 *
 * **La règle, en changeant une page :** modifier le catalogue qui la porte
 * (`landing.*`, `articles.*`, `legal.*`) et avancer sa date ici, dans le même commit. Une
 * refonte visuelle qui ne change pas un mot ne se compte pas : `lastmod` parle du contenu,
 * pas du code. Mentir ici revient à revenir à la date figée, en plus coûteux.
 *
 * Le type force la liste à rester complète : une page ajoutée à `INDEXABLE_PATHS` sans date
 * ici ne compile pas.
 */
const PAGE_UPDATED: Record<IndexablePath, string> = {
  "/": "2026-09-15",
  "/methode": "2026-09-10",
  "/mode-examen": "2026-09-10",
  "/micabo-ou-anki": "2026-09-10",
  "/confidentialite": "2026-09-11",
  "/conditions": "2026-09-11",
};

function absolute(path: string): string {
  return path === "/" ? `${CANONICAL_URL}/` : `${CANONICAL_URL}${path}`;
}

/**
 * Les pages publiques, **dans les cinq langues**.
 *
 * Chaque URL a son jeu `hreflang`, le même que dans le HTML.
 * `x-default` est l'anglais, la version sans préfixe.
 */
export function indexableSitemap(): SitemapEntry[] {
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
      languages: Object.fromEntries(
        Object.entries(languages).map(([lang, href]) => [lang, absolute(href)]),
      ),
    };
    const lastModified = new Date(`${PAGE_UPDATED[path]}T00:00:00.000Z`);
    return UI_LOCALES.map((locale) => {
      const href = localizedPath(locale, path);
      return {
        url: absolute(href),
        lastModified,
        changeFrequency: frequency(path),
        priority: priorityOf(path),
        alternates,
      };
    });
  });
}

/** Les 30 adresses à coller dans Search Console, dans le même ordre que le sitemap. */
export function searchConsoleUrls(): string[] {
  return indexableSitemap().map((entry) => entry.url);
}
