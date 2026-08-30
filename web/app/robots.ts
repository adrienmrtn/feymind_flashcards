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
 */
export default function robots(): MetadataRoute.Robots {
  if (!IS_INDEXABLE) {
    return { rules: { userAgent: "*", disallow: "/" } };
  }

  return {
    rules: {
      userAgent: "*",
      allow: "/",
      // Ces chemins n'ont pas de sens sans session. Les lister ici épargne à Google des
      // milliers de redirections vers la connexion, ce qui est aussi ce qui fait qu'il
      // revient plus souvent sur les pages qui comptent.
      disallow: ["/app/", "/auth/", "/commencer/", "/fondations"],
    },
    // Pas de directive `Host` : Google l'ignore, seul Yandex la lit, et il l'attend sans
    // schéma. Une ligne mal formée coûte plus que l'absence de ligne. C'est la balise
    // canonique qui désigne l'hôte, et elle est comprise partout.
    sitemap: `${CANONICAL_URL}/sitemap.xml`,
  };
}
