import type { Metadata } from "next";

import { CANONICAL_URL } from "@/lib/config";

import { languageAlternatePaths, localizedPath, stripLocalePrefix } from "./paths";
import type { UiLocale } from "./locales";

function absolute(path: string): string {
  return path === "/" ? `${CANONICAL_URL}/` : `${CANONICAL_URL}${path}`;
}

/**
 * Canonique self + `hreflang` des cinq langues.
 *
 * Chaque variante doit lister les quatre autres et `x-default` (anglais).
 * Un oubli, Google jette le jeu entier.
 */
export function indexableAlternates(locale: UiLocale, path: string): NonNullable<Metadata["alternates"]> {
  const rest = stripLocalePrefix(path);
  const map = languageAlternatePaths(rest);
  const languages: Record<string, string> = {};
  for (const [lang, href] of Object.entries(map)) {
    languages[lang] = absolute(href);
  }
  return {
    canonical: localizedPath(locale, rest),
    languages,
  };
}
