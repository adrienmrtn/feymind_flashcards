import type { MetadataRoute } from "next";

import { IS_INDEXABLE, SITE_URL, isProduction } from "@/lib/config";

/**
 * Ce qui doit être indexé, et quand.
 *
 * Une prévisualisation indexée se présente dans les résultats à la place du site, avec une URL
 * qui mourra au déploiement suivant. Elle est donc fermée sans condition. La production l'est
 * aussi pour l'instant : il n'y a pas encore de page d'accueil à trouver.
 */
export default function robots(): MetadataRoute.Robots {
  const allowed = isProduction && IS_INDEXABLE;

  return {
    rules: allowed ? { userAgent: "*", allow: "/" } : { userAgent: "*", disallow: "/" },
    ...(allowed ? { sitemap: `${SITE_URL}/sitemap.xml` } : {}),
  };
}
