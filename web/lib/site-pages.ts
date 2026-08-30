/**
 * **Les pages publiques, nommées une fois.**
 *
 * Le site n'avait que trois adresses, dont deux de droit. Ça ne suffit pas : les liens qui
 * s'affichent sous un résultat de recherche sont choisis par Google **parmi les pages qu'il a
 * explorées**, et une vitrine dont tout le contenu vit dans des ancres n'en offre aucune. Les
 * trois pages ci-dessous existent donc comme pages, avec leur titre, leur adresse et leur
 * place dans le sitemap.
 *
 * Un seul fichier les décrit, et il sert au sitemap, au pied de page, à la barre des pages de
 * contenu et aux liens croisés. Une page ajoutée ici apparaît partout ; une page ajoutée en
 * quatre endroits finit par manquer dans l'un des quatre — le plus souvent le sitemap.
 *
 * `label` est ce qu'un lien écrit, `title` ce que l'onglet et le résultat de recherche
 * affichent. Les deux diffèrent à dessein : « La méthode » suffit dans un pied de page, et
 * ne dit rien dans une page de résultats.
 */

import type { Route } from "next";

export interface SitePage {
  path: Route;
  /** Court, pour un lien. */
  label: string;
  /** Le titre du résultat de recherche. La marque est ajoutée par la charpente. */
  title: string;
  description: string;
  /** Poids relatif dans le sitemap, entre nos pages et elles seules. */
  priority: number;
}

export const METHOD_PAGE: SitePage = {
  path: "/methode" as Route,
  label: "La méthode",
  title: "La méthode : répétition espacée et rappel actif",
  description:
    "Relire un cours ne le fait pas retenir. Ce qu'on retrouve de mémoire tient, surtout si la question revient juste avant l'oubli. Comment Micabo applique la répétition espacée, avec les vrais intervalles.",
  priority: 0.8,
};

export const EXAM_PAGE: SitePage = {
  path: "/mode-examen" as Route,
  label: "Mode examen",
  title: "Le mode examen : donne la date, le plan se resserre",
  description:
    "La répétition espacée ignore le jour J. Le mode examen de Micabo lui donne une date butoir, resserre les passages à l'approche de l'épreuve, et empêche une carte de repartir au-delà.",
  priority: 0.8,
};

export const ANKI_PAGE: SitePage = {
  path: "/micabo-ou-anki" as Route,
  label: "Micabo ou Anki",
  title: "Micabo ou Anki : ce qui change vraiment",
  description:
    "Anki est gratuit, ouvert et excellent. Micabo écrit les cartes à partir de ton cours et replanifie tout autour d'une date d'examen. Comparaison honnête, y compris là où Anki gagne.",
  priority: 0.7,
};

/** Dans l'ordre de lecture : la méthode explique le reste. */
export const SITE_PAGES: readonly SitePage[] = [METHOD_PAGE, EXAM_PAGE, ANKI_PAGE];

/** Les deux autres pages, pour le bloc « à lire ensuite » au pied d'une page. */
export function otherPages(current: SitePage): SitePage[] {
  return SITE_PAGES.filter((page) => page.path !== current.path);
}
