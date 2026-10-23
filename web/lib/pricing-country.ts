import "server-only";

import { cache } from "react";
import { headers } from "next/headers";

import { pricing } from "@micabo/core";

import { readUiLocale } from "@/lib/i18n/server";

/**
 * **Le pays dont on affiche les prix, pour cette requête.**
 *
 * Le pays déclaré au parcours (`profiles.country_code`) gagne : c'est celui que `startCheckout`
 * lit pour la devise encaissée. Sans compte, ou sans pays dans le compte, l'adresse IP
 * (`x-vercel-ip-country`, posé par Vercel), puis la région du navigateur. Le pays choisi au
 * parcours avant l'inscription vit dans le `localStorage` du parcours ; il rejoint
 * `profiles.country_code` à la création du compte.
 *
 * Rend un ISO alpha-2, ou `null` : la grille de base (la France).
 */
export const readPricingCountry = cache(
  async (profileCountry?: string | null): Promise<string | null> => {
    const [head, uiLocale] = await Promise.all([headers(), readUiLocale()]);
    return pricing.resolvePricingCountry({
      profile: profileCountry,
      geo: head.get("x-vercel-ip-country"),
      acceptLanguage: head.get("accept-language"),
      uiLocale,
    });
  },
);
