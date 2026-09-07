/**
 * Une URL publique = une langue.
 *
 * L'anglais n'a pas de préfixe (`/methode`). Le français, l'allemand,
 * l'espagnol et le turc ont le leur (`/fr/methode`, `/tr/methode`). Sans ça,
 * Google n'indexe qu'une version — celle que le robot a vue.
 *
 * Les écrans privés (`/app`, `/commencer`, …) n'ont pas de préfixe : ils sont
 * `noindex`, le cookie suffit.
 */

import type { Route } from "next";

import { DEFAULT_UI_LOCALE, isUiLocale, type UiLocale } from "./locales";

/** Préfixes visibles dans l'adresse. L'anglais n'en a pas. */
export const URL_PREFIX_LOCALES = ["fr", "de", "es", "tr"] as const;
export type UrlPrefixLocale = (typeof URL_PREFIX_LOCALES)[number];

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
  const first = segments[0];
  if (!isUiLocale(first)) return { prefix: null, rest: clean };
  const rest = segments.length === 1 ? "/" : `/${segments.slice(1).join("/")}`;
  return { prefix: first, rest };
}

export function stripLocalePrefix(pathname: string): string {
  return splitLocalePrefix(pathname).rest;
}

/** Chemin public dans une langue. `en` + `/methode` → `/methode`. `fr` + `/` → `/fr`. */
export function localizedPath(locale: UiLocale, path: string): string {
  const rest = normalizePath(stripLocalePrefix(path));
  if (locale === DEFAULT_UI_LOCALE) return rest;
  return rest === "/" ? `/${locale}` : `/${locale}${rest}`;
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

export type LanguageAlternateMap = {
  en: string;
  fr: string;
  de: string;
  es: string;
  tr: string;
  "x-default": string;
};

/** Jeu `hreflang` réciproque + `x-default` = anglais. */
export function languageAlternatePaths(path: string): LanguageAlternateMap {
  const rest = stripLocalePrefix(path);
  return {
    en: localizedPath("en", rest),
    fr: localizedPath("fr", rest),
    de: localizedPath("de", rest),
    es: localizedPath("es", rest),
    tr: localizedPath("tr", rest),
    "x-default": localizedPath("en", rest),
  };
}
