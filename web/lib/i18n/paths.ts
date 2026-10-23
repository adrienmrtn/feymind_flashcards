/**
 * Une URL publique = une langue.
 *
 * L'anglais n'a pas de préfixe (`/methode`). Les vingt-cinq autres langues ont le leur, le
 * code en minuscules (`/fr/methode`, `/pt-br/methode`, `/es-419/methode`). Sans ça, Google
 * n'indexe qu'une version — celle que le robot a vue.
 *
 * Les écrans privés (`/app`, `/commencer`, …) n'ont pas de préfixe : ils sont
 * `noindex`, le cookie suffit.
 */

import type { Route } from "next";

import {
  DEFAULT_UI_LOCALE,
  UI_LOCALES,
  UI_LOCALE_META,
  isUiLocale,
  localeFromUrlSegment,
  urlSegment,
  type UiLocale,
} from "./locales";

/** Les langues qui ont un préfixe dans l'adresse : toutes, sauf l'anglais. */
export type UrlPrefixLocale = Exclude<UiLocale, "en">;
export const URL_PREFIX_LOCALES = UI_LOCALES.filter(
  (locale): locale is UrlPrefixLocale => locale !== DEFAULT_UI_LOCALE,
);

/** Header posé par le middleware : la langue de l'URL, pas celle du cookie. */
export const LOCALE_HEADER = "x-micabo-locale";

export const INDEXABLE_PATHS = [
  "/",
  "/methode",
  "/mode-examen",
  "/micabo-ou-anki",
  "/confidentialite",
  "/conditions",
] as const;

/** Une page publique, sans son préfixe de langue. `PAGE_UPDATED` la veut datée. */
export type IndexablePath = (typeof INDEXABLE_PATHS)[number];

const PRIVATE_PREFIXES = ["/app", "/commencer", "/connexion", "/auth", "/fondations"] as const;

const LOCALE_BLIND = [
  "/sitemap.xml",
  "/robots.txt",
  "/opengraph-image",
  "/manifest.webmanifest",
] as const;

export function isUrlPrefixLocale(value: string | undefined | null): value is UrlPrefixLocale {
  return URL_PREFIX_LOCALES.includes(value as UrlPrefixLocale);
}

export function normalizePath(path: string): string {
  if (!path || path === "/") return "/";
  const withSlash = path.startsWith("/") ? path : `/${path}`;
  return withSlash.length > 1 && withSlash.endsWith("/") ? withSlash.slice(0, -1) : withSlash;
}

export function splitLocalePrefix(pathname: string): {
  prefix: UiLocale | null;
  rest: string;
} {
  const clean = normalizePath(pathname);
  if (clean === "/") return { prefix: null, rest: "/" };
  const segments = clean.slice(1).split("/");
  const prefix = localeFromUrlSegment(segments[0]);
  if (!prefix) return { prefix: null, rest: clean };
  const rest = segments.length === 1 ? "/" : `/${segments.slice(1).join("/")}`;
  return { prefix, rest };
}

/** Le préfixe est-il écrit comme on l'écrit (`/pt-br`), et pas `/pt-BR` ou `/FR` ? */
function hasCanonicalPrefix(pathname: string, prefix: UiLocale): boolean {
  return normalizePath(pathname).slice(1).split("/")[0] === urlSegment(prefix);
}

export function stripLocalePrefix(pathname: string): string {
  return splitLocalePrefix(pathname).rest;
}

/**
 * Chemin public dans une langue. `en` + `/methode` → `/methode`. `fr` + `/` → `/fr`.
 * `pt-BR` + `/methode` → `/pt-br/methode` : l'adresse s'écrit en minuscules.
 */
export function localizedPath(locale: UiLocale, path: string): string {
  const rest = normalizePath(stripLocalePrefix(path));
  if (locale === DEFAULT_UI_LOCALE) return rest;
  const segment = urlSegment(locale);
  return rest === "/" ? `/${segment}` : `/${segment}${rest}`;
}

export function localizedHref(locale: UiLocale, path: string): Route {
  return localizedPath(locale, path) as Route;
}

export function isPrivatePath(pathname: string): boolean {
  const rest = stripLocalePrefix(pathname);
  return PRIVATE_PREFIXES.some((prefix) => rest === prefix || rest.startsWith(`${prefix}/`));
}

export function isLocaleBlindPath(pathname: string): boolean {
  const rest = stripLocalePrefix(pathname);
  if (LOCALE_BLIND.includes(rest as (typeof LOCALE_BLIND)[number])) return true;
  if (rest.startsWith("/auth/")) return true;
  if (/^\/google[^/]+\.html$/.test(rest)) return true;
  return false;
}

export function isIndexablePath(pathname: string): boolean {
  const rest = stripLocalePrefix(pathname);
  return (INDEXABLE_PATHS as readonly string[]).includes(rest);
}

export type LocaleResolution =
  | { action: "redirect"; location: string; status: 301 | 302; setCookie?: UiLocale }
  | { action: "continue"; pathname: string; urlLocale: UiLocale | null; setCookie?: UiLocale };

/**
 * Décide, à partir de l'adresse seule, ce que le middleware doit faire.
 *
 * Pas de cookie, pas de `Accept-Language` : une URL publique sert toujours
 * la même langue, robot compris.
 */
export function resolveLocaleRequest(pathname: string): LocaleResolution {
  const { prefix, rest } = splitLocalePrefix(pathname);

  if (prefix === DEFAULT_UI_LOCALE) {
    return { action: "redirect", location: rest, status: 301 };
  }

  if (prefix && isUrlPrefixLocale(prefix)) {
    if (isPrivatePath(rest) || isLocaleBlindPath(rest)) {
      return { action: "redirect", location: rest, status: 302, setCookie: prefix };
    }
    // `/pt-BR/methode` et `/FR` mènent à la bonne page, mais sous une seule adresse :
    // deux casses du même préfixe seraient deux URL du même contenu.
    if (!hasCanonicalPrefix(pathname, prefix)) {
      return { action: "redirect", location: localizedPath(prefix, rest), status: 301 };
    }
    return { action: "continue", pathname: rest, urlLocale: prefix, setCookie: prefix };
  }

  if (isPrivatePath(pathname) || isLocaleBlindPath(pathname)) {
    return { action: "continue", pathname: normalizePath(pathname), urlLocale: null };
  }

  return { action: "continue", pathname: normalizePath(pathname), urlLocale: DEFAULT_UI_LOCALE };
}

/**
 * Header à poser sur la requête.
 *
 * Une adresse préfixée (`/fr`) se réécrit en `/`, et le middleware
 * tourne une deuxième fois sur le chemin nu. Sans garder le header de
 * la première passe, la version de base écraserait la langue de l'URL.
 */
export function forwardedUrlLocale(
  incoming: string | null,
  resolved: UiLocale | null,
): UiLocale | null {
  if (isUiLocale(incoming)) return incoming;
  return resolved;
}

/**
 * Où aller après un changement de langue.
 *
 * Page indexable : l'adresse décide, donc on navigue (`/methode` → `/fr/methode`).
 * Écran privé : le cookie suffit, on reste.
 */
export function localeSwitchHref(pathname: string, next: UiLocale): string | null {
  const rest = stripLocalePrefix(pathname);
  if (!isIndexablePath(rest)) return null;
  return localizedPath(next, rest);
}

/** `hreflang` → chemin. Les clés sont `UI_LOCALE_META[…].hreflang` (`pt-BR`, `sr`), plus `x-default`. */
export type LanguageAlternateMap = Record<string, string> & { "x-default": string };

/**
 * Jeu `hreflang` réciproque + `x-default` = anglais.
 *
 * `locales` : les langues à annoncer. Toutes par défaut ; le sitemap et les métadonnées ne
 * passent que celles qui ont leur traduction (`TRANSLATED_UI_LOCALES`) — l'anglais servi
 * sous `/it` n'est pas une version italienne.
 */
export function languageAlternatePaths(
  path: string,
  locales: readonly UiLocale[] = UI_LOCALES,
): LanguageAlternateMap {
  const rest = stripLocalePrefix(path);
  const map: Record<string, string> = {};
  for (const locale of locales) {
    map[UI_LOCALE_META[locale].hreflang] = localizedPath(locale, rest);
  }
  return { ...map, "x-default": localizedPath(DEFAULT_UI_LOCALE, rest) };
}
