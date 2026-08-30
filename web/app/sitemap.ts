import type { MetadataRoute } from "next";

import { CANONICAL_URL } from "@/lib/config";

/**
 * Les pages publiques, et rien d'autre.
 *
 * Un sitemap n'améliore pas un classement : il dit à Google **quoi lire et dans quel
 * ordre**. Y mettre les écrans de l'app connectée serait pire que de ne rien mettre, parce
 * que chacun répond par une redirection vers la connexion et fait baisser la confiance
 * accordée au fichier entier.
 *
 * `priority` est relatif à ce seul fichier : il ne compare pas Micabo à un autre site, il
 * dit lequel de nos écrans compte le plus si Google n'a le temps que d'un.
 */
export default function sitemap(): MetadataRoute.Sitemap {
  const updated = new Date("2026-08-30");

  return [
    {
      url: `${CANONICAL_URL}/`,
      lastModified: updated,
      changeFrequency: "weekly",
      priority: 1,
    },
    {
      url: `${CANONICAL_URL}/confidentialite`,
      lastModified: updated,
      changeFrequency: "yearly",
      priority: 0.3,
    },
    {
      url: `${CANONICAL_URL}/conditions`,
      lastModified: updated,
      changeFrequency: "yearly",
      priority: 0.3,
    },
  ];
}
