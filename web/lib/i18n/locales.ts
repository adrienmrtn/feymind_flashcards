/**
 * La langue de l'interface web. Pas celle des fiches (`sheet_language`).
 *
 * Cookie, pas colonne : c'est le même contrat que `UiLocale.storageKey` côté iPhone, et un
 * réglage écrit dans `profiles` se synchroniserait là-bas sans rien à afficher.
 *
 * **Les vingt-six langues des apps**, dans l'ordre de `UiLocale.swift` : l'anglais d'abord —
 * c'est la langue de base, celle qu'on sert quand le navigateur n'en désigne aucune autre —,
 * puis les marchés, de l'Europe au Moyen-Orient et à l'Amérique latine. Deux variantes
 * régionales ont leur propre catalogue : `es-419` (Amérique latine) à côté d'`es` (Espagne),
 * `pt-BR` (Brésil) à côté de `pt` (Portugal).
 *
 * Les codes sont ceux du cookie et du header `x-micabo-locale`. L'adresse, elle, les écrit en
 * minuscules (`/pt-br/methode`) : voir `urlSegment`.
 */

export const UI_LOCALES = [
  "en",
  "fr",
  "de",
  "es",
  "es-419",
  "it",
  "pt",
  "pt-BR",
  "nl",
  "pl",
  "ro",
  "sv",
  "da",
  "fi",
  "et",
  "cs",
  "sk",
  "hu",
  "hr",
  "sl",
  "sr",
  "bg",
  "el",
  "ru",
  "tr",
  "ar",
] as const;
export type UiLocale = (typeof UI_LOCALES)[number];

export const DEFAULT_UI_LOCALE: UiLocale = "en";
export const UI_LOCALE_COOKIE = "micabo.ui_locale";

export type UiLocaleMeta = {
  /** `<html lang>` : le serbe s'écrit en latin (`sr-Latn`), comme dans l'app. */
  html: string;
  /** La locale d'`Intl` : nombres, dates, monnaies. */
  bcp47: string;
  /** `og:locale`, au format de Facebook (`pt_BR`, `es_LA`, `ar_AR`). */
  og: string;
  /** L'attribut `hreflang` : langue, et région quand une variante existe à côté. */
  hreflang: string;
  /** Le nom de la langue, écrit dans cette langue : c'est ainsi qu'on la reconnaît. */
  native: string;
  /** Drapeau du pays de référence (le même que l'app). Une langue n'est pas un pays. */
  flag: string;
  /** Le sens de lecture. Seul l'arabe se lit de droite à gauche. */
  dir: "ltr" | "rtl";
};

function meta(
  html: string,
  bcp47: string,
  og: string,
  native: string,
  flag: string,
  options: { hreflang?: string; dir?: "ltr" | "rtl" } = {},
): UiLocaleMeta {
  return { html, bcp47, og, hreflang: options.hreflang ?? html, native, flag, dir: options.dir ?? "ltr" };
}

export const UI_LOCALE_META: Record<UiLocale, UiLocaleMeta> = {
  en: meta("en", "en-US", "en_US", "English", "🇬🇧"),
  fr: meta("fr", "fr-FR", "fr_FR", "Français", "🇫🇷"),
  de: meta("de", "de-DE", "de_DE", "Deutsch", "🇩🇪"),
  es: meta("es", "es-ES", "es_ES", "Español (España)", "🇪🇸"),
  "es-419": meta("es-419", "es-419", "es_LA", "Español (Latinoamérica)", "🇲🇽"),
  it: meta("it", "it-IT", "it_IT", "Italiano", "🇮🇹"),
  pt: meta("pt", "pt-PT", "pt_PT", "Português (Portugal)", "🇵🇹"),
  "pt-BR": meta("pt-BR", "pt-BR", "pt_BR", "Português (Brasil)", "🇧🇷"),
  nl: meta("nl", "nl-NL", "nl_NL", "Nederlands", "🇳🇱"),
  pl: meta("pl", "pl-PL", "pl_PL", "Polski", "🇵🇱"),
  ro: meta("ro", "ro-RO", "ro_RO", "Română", "🇷🇴"),
  sv: meta("sv", "sv-SE", "sv_SE", "Svenska", "🇸🇪"),
  da: meta("da", "da-DK", "da_DK", "Dansk", "🇩🇰"),
  fi: meta("fi", "fi-FI", "fi_FI", "Suomi", "🇫🇮"),
  et: meta("et", "et-EE", "et_EE", "Eesti", "🇪🇪"),
  cs: meta("cs", "cs-CZ", "cs_CZ", "Čeština", "🇨🇿"),
  sk: meta("sk", "sk-SK", "sk_SK", "Slovenčina", "🇸🇰"),
  hu: meta("hu", "hu-HU", "hu_HU", "Magyar", "🇭🇺"),
  hr: meta("hr", "hr-HR", "hr_HR", "Hrvatski", "🇭🇷"),
  sl: meta("sl", "sl-SI", "sl_SI", "Slovenščina", "🇸🇮"),
  // Le serbe de Micabo s'écrit en alphabet latin (`sr-Latn.lproj` côté iPhone). `hreflang`
  // reste `sr` : Google lit une langue et une région, pas une écriture.
  sr: meta("sr-Latn", "sr-Latn-RS", "sr_RS", "Srpski", "🇷🇸", { hreflang: "sr" }),
  bg: meta("bg", "bg-BG", "bg_BG", "Български", "🇧🇬"),
  el: meta("el", "el-GR", "el_GR", "Ελληνικά", "🇬🇷"),
  ru: meta("ru", "ru-RU", "ru_RU", "Русский", "🇷🇺"),
  tr: meta("tr", "tr-TR", "tr_TR", "Türkçe", "🇹🇷"),
  ar: meta("ar", "ar-AE", "ar_AR", "العربية", "🇦🇪", { dir: "rtl" }),
};

export function isUiLocale(value: string | undefined | null): value is UiLocale {
  return UI_LOCALES.includes(value as UiLocale);
}

/** Le segment d'adresse d'une langue : le code, en minuscules (`pt-BR` → `pt-br`). */
export function urlSegment(locale: UiLocale): string {
  return locale.toLowerCase();
}

/** L'inverse d'`urlSegment`, sans tenir compte de la casse (`pt-BR`, `pt-br` → `pt-BR`). */
export function localeFromUrlSegment(segment: string | undefined | null): UiLocale | null {
  if (!segment) return null;
  const lower = segment.toLowerCase();
  return UI_LOCALES.find((locale) => locale.toLowerCase() === lower) ?? null;
}

/**
 * L'espagnol d'Amérique (latine, et des États-Unis) : `es-419` plutôt qu'`es`.
 * Les régions sont celles d'ISO 3166-1, plus `419`, le code de l'ONU pour toute la zone.
 */
const LATIN_AMERICAN_SPANISH = new Set([
  "419", "ar", "bo", "cl", "co", "cr", "cu", "do", "ec", "gt", "hn", "mx",
  "ni", "pa", "pe", "pr", "py", "sv", "us", "uy", "ve",
]);

/** Le Portugal et l'Afrique lusophone écrivent le portugais européen ; le reste, le brésilien. */
const EUROPEAN_PORTUGUESE = new Set(["pt", "ao", "mz", "cv", "gw", "st", "tl", "mo"]);

/** Une étiquette du navigateur (`es-MX`, `pt_BR`, `sr-Latn-RS`) → une de nos langues, ou rien. */
export function matchLanguageTag(raw: string | undefined | null): UiLocale | null {
  const tag = raw?.trim().replace(/_/g, "-").toLowerCase();
  if (!tag || tag === "*") return null;

  // L'étiquette entière d'abord : `pt-br`, `es-419`.
  const exact = UI_LOCALES.find((locale) => locale.toLowerCase() === tag);
  if (exact) return exact;

  const [primary, ...rest] = tag.split("-");
  // La région est le premier sous-élément de deux lettres ou de trois chiffres ; une écriture
  // (`latn`, quatre lettres) se saute.
  const region = rest.find((part) => /^[a-z]{2}$|^\d{3}$/.test(part));

  if (primary === "es") return region && LATIN_AMERICAN_SPANISH.has(region) ? "es-419" : "es";
  if (primary === "pt") return region && !EUROPEAN_PORTUGUESE.has(region) ? "pt-BR" : "pt";
  // Le bosnien, le serbo-croate et le monténégrin se lisent dans la même langue que le
  // croate de l'app — c'est le choix d'`UiLocale.fromPreferredLanguages` côté iPhone.
  if (primary === "bs" || primary === "sh" || primary === "cnr") return "hr";

  // Puis la langue seule : `fr-ca` → `fr`, `sr-latn-rs` → `sr`.
  return UI_LOCALES.find((locale) => locale === primary) ?? null;
}

/**
 * `Accept-Language` → une de nos langues, ou **rien**.
 *
 * Le `null` porte une information que le repli efface : le navigateur n'a désigné aucune
 * langue qu'on sache parler. Ailleurs on affiche l'anglais et c'est très bien ; mais la page
 * de paiement, elle, a encore le pays à consulter avant de conclure quoi que ce soit.
 *
 * Les langues se lisent dans l'ordre de l'en-tête : un navigateur réglé « japonais, puis
 * portugais du Brésil » tombe sur `pt-BR`, pas sur l'anglais.
 */
export function matchAcceptLanguage(header: string | null): UiLocale | null {
  if (!header) return null;
  for (const part of header.split(",")) {
    const match = matchLanguageTag(part.split(";")[0]);
    if (match) return match;
  }
  return null;
}

/** `Accept-Language` → une de nos langues, sinon l'anglais. */
export function localeFromAcceptLanguage(header: string | null): UiLocale {
  return matchAcceptLanguage(header) ?? DEFAULT_UI_LOCALE;
}
