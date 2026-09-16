import type { MetadataRoute } from "next";

import { CANONICAL_URL, IS_INDEXABLE } from "@/lib/config";

/**
 * Ce qui doit être exploré, et ce qui ne doit pas l'être.
 *
 * Le site a longtemps répondu `Disallow: /`. C'est ce que la Search Console dit quand elle
 * annonce ne pas avoir pu lire la page pour en tirer un extrait : sans exploration, Google
 * peut encore indexer l'adresse, mais il n'a aucun texte à montrer dessous.
 *
 * `Disallow` n'est pas un `noindex`, et les deux ne s'empilent pas : une page interdite à
 * l'exploration ne peut **pas** être lue, donc son `noindex` ne peut pas être vu. Les écrans
 * privés sont donc fermés par en-tête `X-Robots-Tag` (`next.config.ts`) et laissés
 * explorables ici, sinon la consigne n'arriverait jamais.
 *
 * **Il n'y a donc aucune ligne `Disallow` en production, et c'est le sujet du fichier.**
 * Il y en a eu quatre — `/app/`, `/auth/`, `/commencer/`, `/fondations` — posées pour
 * épargner à Google des redirections vers la connexion. Elles interdisaient exactement les
 * chemins que `next.config.ts` marque `noindex, follow` : la consigne était écrite dans une
 * pièce dont on venait de fermer la porte. Un chemin bloqué ici ne sort jamais de l'index,
 * il y reste en adresse nue, sans titre ni extrait, et la Search Console le range sous
 * « explorée, actuellement non indexée » ou « bloquée par le fichier robots.txt ».
 *
 * L'économie d'exploration était par ailleurs illusoire : un écran privé est vu une fois,
 * rend `noindex`, et Google cesse d'y revenir. C'est moins cher qu'une adresse bloquée pour
 * toujours, que le moteur retente indéfiniment parce que rien ne lui a jamais dit non.
 *
 * Ce qui reste ici : l'adresse du sitemap, et l'ouverture.
 */
export default function robots(): MetadataRoute.Robots {
  if (!IS_INDEXABLE) {
    return { rules: { userAgent: "*", disallow: "/" } };
  }

  return {
    rules: {
      userAgent: "*",
      allow: "/",
    },
    // Pas de directive `Host` : Google l'ignore, seul Yandex la lit, et il l'attend sans
    // schéma. Une ligne mal formée coûte plus que l'absence de ligne. C'est la balise
    // canonique qui désigne l'hôte, et elle est comprise partout.
    sitemap: `${CANONICAL_URL}/sitemap.xml`,
  };
}
