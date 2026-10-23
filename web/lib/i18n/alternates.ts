import type { Metadata } from "next";

import { CANONICAL_URL } from "@/lib/config";

import { TRANSLATED_UI_LOCALES, isTranslatedLocale } from "./catalogs";
import { languageAlternatePaths, localizedPath, stripLocalePrefix } from "./paths";
import { DEFAULT_UI_LOCALE, type UiLocale } from "./locales";

function absolute(path: string): string {
  return path === "/" ? `${CANONICAL_URL}/` : `${CANONICAL_URL}${path}`;
}

/**
 * Canonique self + `hreflang` de toutes les langues traduites.
 *
 * Chaque variante doit lister toutes les autres et `x-default` (anglais).
 * Un oubli, Google jette le jeu entier.
 *
 * Une langue encore sans catalogue (`CATALOGS.it === en`) sert l'anglais sous son préfixe :
 * sa canonique pointe sur la version anglaise, et elle n'entre pas dans le jeu. Le jour où
 * sa traduction est branchée, elle s'y ajoute d'elle-même.
 */
export function indexableAlternates(locale: UiLocale, path: string): NonNullable<Metadata["alternates"]> {
  const rest = stripLocalePrefix(path);
  const map = languageAlternatePaths(rest, TRANSLATED_UI_LOCALES);
  const languages: Record<string, string> = {};
  for (const [lang, href] of Object.entries(map)) {
    languages[lang] = absolute(href);
  }
  return {
    canonical: localizedPath(isTranslatedLocale(locale) ? locale : DEFAULT_UI_LOCALE, rest),
    languages,
  };
}
