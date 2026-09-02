/**
 * La langue de l'interface web. Pas celle des fiches (`sheet_language`).
 *
 * Cookie, pas colonne : l'iPhone n'en sait rien encore, et un réglage écrit
 * dans `profiles` se synchroniserait là-bas sans rien à afficher.
 */

export const UI_LOCALES = ["fr", "de", "es", "tr"] as const;
export type UiLocale = (typeof UI_LOCALES)[number];

export const DEFAULT_UI_LOCALE: UiLocale = "fr";
export const UI_LOCALE_COOKIE = "micabo.ui_locale";

export const UI_LOCALE_META: Record<
  UiLocale,
  { html: string; bcp47: string; og: string; native: string }
> = {
  fr: { html: "fr", bcp47: "fr-FR", og: "fr_FR", native: "Français" },
  de: { html: "de", bcp47: "de-DE", og: "de_DE", native: "Deutsch" },
  es: { html: "es", bcp47: "es-ES", og: "es_ES", native: "Español" },
  tr: { html: "tr", bcp47: "tr-TR", og: "tr_TR", native: "Türkçe" },
};

export function isUiLocale(value: string | undefined | null): value is UiLocale {
  return UI_LOCALES.includes(value as UiLocale);
}

/** `Accept-Language` → une de nos langues, sinon le français. */
export function localeFromAcceptLanguage(header: string | null): UiLocale {
  if (!header) return DEFAULT_UI_LOCALE;
  for (const part of header.split(",")) {
    const tag = part.split(";")[0]?.trim().toLowerCase();
    if (!tag) continue;
    const primary = tag.split("-")[0];
    if (isUiLocale(primary)) return primary;
  }
  return DEFAULT_UI_LOCALE;
}
