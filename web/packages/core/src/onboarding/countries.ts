/**
 * Le pays de scolarisation, porté depuis `SchoolingCountry`.
 *
 * C'est la **première** question du parcours, et pas par politesse géographique : c'est elle qui
 * commande les réponses de « qu'est-ce qui te décrit le mieux ? », et elle décide aussi de la
 * langue dans laquelle Micabo écrit. Dans l'autre sens, il faudrait servir les mêmes sept réponses
 * françaises à tout le monde — ce qui ne laisse aucune réponse juste à un Polonais ou à un Turc.
 *
 * **L'ordre de la liste est l'ordre d'affichage**, et il n'est pas alphabétique : ce sont les
 * marchés visés en premier qui se lisent en premier. Les pays francophones historiques suivent,
 * parce qu'ils restent servis mais ne sont plus ce qu'on cherche d'abord.
 *
 * « Autre pays » n'a plus d'échelle inventée : l'écran ouvre un champ où l'on **écrit** son pays,
 * et le nom choisi est gardé à côté. Un menu déroulant de deux cents entrées se parcourt moins vite
 * qu'un mot tapé.
 */

export type CountryCode =
  | "fr"
  | "uk"
  | "de"
  | "it"
  | "es"
  | "pt"
  | "cz"
  | "nl"
  | "gr"
  | "hu"
  | "pl"
  | "ro"
  | "se"
  | "tr"
  | "be"
  | "ch"
  | "ca"
  | "lu"
  | "ma"
  | "dz"
  | "tn"
  | "sn"
  | "ci"
  | "us"
  | "other";

/**
 * La langue de sortie du modèle.
 *
 * Les codes sont ceux d'ISO 639-1 et ne suivent pas toujours le pays : la Tchéquie écrit `cs`, la
 * Grèce `el`, la Suède `sv`. C'est cette table qui fait la traduction, et c'est la même liste que
 * `supabase/functions/_shared/language.ts`.
 */
export type ContentLanguage =
  | "fr"
  | "en"
  | "de"
  | "it"
  | "es"
  | "pt"
  | "cs"
  | "nl"
  | "el"
  | "hu"
  | "pl"
  | "ro"
  | "sv"
  | "tr";

/** Le nom de la langue, écrit dans cette langue : c'est ainsi qu'on choisit une langue. */
export const LANGUAGE_LABELS: Record<ContentLanguage, string> = {
  fr: "Français",
  en: "English",
  de: "Deutsch",
  it: "Italiano",
  es: "Español",
  pt: "Português",
  cs: "Čeština",
  nl: "Nederlands",
  el: "Ελληνικά",
  hu: "Magyar",
  pl: "Polski",
  ro: "Română",
  sv: "Svenska",
  tr: "Türkçe",
};

export interface Country {
  code: CountryCode;
  name: string;
  flag: string;
  /** Le code ISO 3166-1 alpha-2, pour dessiner le drapeau autrement qu'en emoji. */
  iso: string;
  language: ContentLanguage;
}

function country(
  code: CountryCode,
  name: string,
  iso: string,
  flag: string,
  language: ContentLanguage,
): Country {
  return { code, name, iso, flag, language };
}

export const COUNTRIES: readonly Country[] = [
  country("fr", "France", "fr", "🇫🇷", "fr"),
  country("uk", "Royaume-Uni", "gb", "🇬🇧", "en"),
  country("de", "Allemagne", "de", "🇩🇪", "de"),
  country("it", "Italie", "it", "🇮🇹", "it"),
  country("es", "Espagne", "es", "🇪🇸", "es"),
  country("pt", "Portugal", "pt", "🇵🇹", "pt"),
  country("cz", "Tchéquie", "cz", "🇨🇿", "cs"),
  country("nl", "Pays-Bas", "nl", "🇳🇱", "nl"),
  country("gr", "Grèce", "gr", "🇬🇷", "el"),
  country("hu", "Hongrie", "hu", "🇭🇺", "hu"),
  country("pl", "Pologne", "pl", "🇵🇱", "pl"),
  country("ro", "Roumanie", "ro", "🇷🇴", "ro"),
  country("se", "Suède", "se", "🇸🇪", "sv"),
  country("tr", "Turquie", "tr", "🇹🇷", "tr"),

  country("be", "Belgique", "be", "🇧🇪", "fr"),
  country("ch", "Suisse", "ch", "🇨🇭", "fr"),
  country("ca", "Canada", "ca", "🇨🇦", "fr"),
  country("lu", "Luxembourg", "lu", "🇱🇺", "fr"),
  country("ma", "Maroc", "ma", "🇲🇦", "fr"),
  country("dz", "Algérie", "dz", "🇩🇿", "fr"),
  country("tn", "Tunisie", "tn", "🇹🇳", "fr"),
  country("sn", "Sénégal", "sn", "🇸🇳", "fr"),
  country("ci", "Côte d'Ivoire", "ci", "🇨🇮", "fr"),
  country("us", "États-Unis", "us", "🇺🇸", "en"),

  country("other", "Autre pays", "", "🌍", "en"),
];

/**
 * Ce que Micabo suppose quand la question n'a pas été posée : le pays de la grande majorité des
 * utilisateurs, et le seul que l'app connaissait avant.
 */
export const FALLBACK_COUNTRY: CountryCode = "fr";

export function countryFor(code: string | null | undefined): Country {
  return COUNTRIES.find((item) => item.code === code) ?? COUNTRIES[0]!;
}

export function languageFor(code: string | null | undefined): ContentLanguage {
  return countryFor(code).language;
}

export function languageLabel(code: string | null | undefined): string {
  return LANGUAGE_LABELS[languageFor(code)];
}

export const CONTENT_LANGUAGES = Object.keys(LANGUAGE_LABELS) as ContentLanguage[];

export function isContentLanguage(value: string | null | undefined): value is ContentLanguage {
  return Boolean(value && value in LANGUAGE_LABELS);
}

/**
 * La langue des **prochaines** fiches.
 *
 * Un réglage explicite gagne. Sinon on retombe sur celle du pays. Les fiches
 * déjà écrites ne passent pas par ici.
 */
export function sheetLanguage(
  preferred: string | null | undefined,
  countryCode?: string | null,
): ContentLanguage {
  if (isContentLanguage(preferred)) return preferred;
  return languageFor(countryCode);
}

/**
 * Le drapeau déduit d'un code ISO : deux lettres devenues indicateurs régionaux.
 *
 * Les emojis de drapeaux n'ont pas de nom propre en Unicode — c'est la seule façon de les obtenir
 * sans écrire deux cents caractères à la main, et c'est ce que fait `WorldCountry.flag` côté iOS.
 */
export function flagFor(iso: string): string {
  const letters = iso.trim().toUpperCase();
  if (letters.length !== 2) return "🌍";

  const base = 0x1f1e6;
  const points = [...letters].map((letter) => {
    const value = letter.charCodeAt(0);
    return value >= 65 && value <= 90 ? base + value - 65 : null;
  });

  if (points.some((point) => point === null)) return "🌍";
  return String.fromCodePoint(...(points as number[]));
}

/**
 * Le pays deviné depuis la locale du navigateur, pour le poser **en évidence**.
 *
 * C'est une suggestion, jamais une réponse : la question reste posée et se répond d'un appui. Une
 * locale dit la langue du navigateur, pas le pays où l'on étudie — un Belge en français et un
 * Français ont la même, et c'est justement pour ça que la région compte plus que la langue.
 */
export function guessCountry(locales: readonly string[]): CountryCode {
  for (const locale of locales) {
    const region = regionOf(locale);
    if (!region) continue;
    // Le Royaume-Uni s'écrit `GB` dans une locale et `uk` dans notre table.
    if (region === "gb") return "uk";
    const match = COUNTRIES.find((item) => item.code === region);
    if (match) return match.code;
  }
  return FALLBACK_COUNTRY;
}

function regionOf(locale: string): string | null {
  const parts = locale.split("-");
  const last = parts[parts.length - 1];
  return last && last.length === 2 ? last.toLowerCase() : null;
}
