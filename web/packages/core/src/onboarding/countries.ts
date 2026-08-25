/**
 * Le pays de scolarisation, porté depuis `SchoolingCountry`.
 *
 * C'est la **première** question du parcours, et pas par politesse géographique : c'est elle qui
 * commande les réponses de « qu'est-ce qui te décrit le mieux ? », et elle décide aussi de la
 * langue dans laquelle Micabo écrit. Dans l'autre sens, il faudrait servir les mêmes sept réponses
 * françaises à tout le monde — ce qui ne laisse aucune réponse juste à un Américain, un
 * Britannique ou un Québécois.
 *
 * « Ailleurs » n'est pas un aveu d'échec : la liste ne peut pas couvrir le monde, et une échelle
 * générique vaut mieux que des paliers inventés.
 */

export type CountryCode =
  | "fr"
  | "be"
  | "ch"
  | "ca"
  | "ma"
  | "dz"
  | "tn"
  | "sn"
  | "ci"
  | "lu"
  | "uk"
  | "us"
  | "other";

export type ContentLanguage = "fr" | "en";

export interface Country {
  code: CountryCode;
  name: string;
  flag: string;
  /** Le système scolaire, dit en trois mots. C'est ce qui justifie la question. */
  systemHint: string;
  language: ContentLanguage;
}

export const COUNTRIES: readonly Country[] = [
  { code: "fr", name: "France", flag: "🇫🇷", systemHint: "Brevet, bac, prépa, PASS", language: "fr" },
  { code: "be", name: "Belgique", flag: "🇧🇪", systemHint: "CESS, bachelier, master", language: "fr" },
  { code: "ch", name: "Suisse", flag: "🇨🇭", systemHint: "Maturité, bachelor, master", language: "fr" },
  { code: "ca", name: "Canada", flag: "🇨🇦", systemHint: "Secondaire, cégep, université", language: "fr" },
  { code: "ma", name: "Maroc", flag: "🇲🇦", systemHint: "Bac marocain, prépa, concours", language: "fr" },
  { code: "dz", name: "Algérie", flag: "🇩🇿", systemHint: "Bac algérien, licence, master", language: "fr" },
  { code: "tn", name: "Tunisie", flag: "🇹🇳", systemHint: "Bac tunisien, licence, mastère", language: "fr" },
  { code: "sn", name: "Sénégal", flag: "🇸🇳", systemHint: "Bac, licence, grandes écoles", language: "fr" },
  { code: "ci", name: "Côte d'Ivoire", flag: "🇨🇮", systemHint: "Bac, licence, grandes écoles", language: "fr" },
  { code: "lu", name: "Luxembourg", flag: "🇱🇺", systemHint: "Diplôme de fin d'études, bachelor", language: "fr" },
  { code: "uk", name: "Royaume-Uni", flag: "🇬🇧", systemHint: "GCSE, A-Levels, university", language: "en" },
  { code: "us", name: "États-Unis", flag: "🇺🇸", systemHint: "High school, college, grad school", language: "en" },
  { code: "other", name: "Ailleurs", flag: "🌍", systemHint: "Middle school, high school, college", language: "en" },
];

/**
 * Ce que Micabo suppose quand la question n'a pas été posée : le pays de la grande majorité des
 * utilisateurs, et le seul que l'app connaissait avant.
 */
export const FALLBACK_COUNTRY: CountryCode = "fr";

export function countryFor(code: string | null | undefined): Country {
  return COUNTRIES.find((country) => country.code === code) ?? countryFor(FALLBACK_COUNTRY)!;
}

export function languageFor(code: string | null | undefined): ContentLanguage {
  return countryFor(code).language;
}

/**
 * Le pays deviné depuis la locale du navigateur, pour le poser **en premier et déjà en
 * évidence**.
 *
 * C'est une suggestion, jamais une réponse : la question reste posée et se répond d'un appui. Une
 * locale dit la langue du navigateur, pas le pays où l'on étudie — un Belge en français et un
 * Français ont la même, et c'est justement pour ça que la région compte plus que la langue.
 */
export function guessCountry(locales: readonly string[]): CountryCode {
  for (const locale of locales) {
    const region = regionOf(locale);
    if (!region) continue;
    const match = COUNTRIES.find((country) => country.code === region);
    if (match) return match.code;
    // Le Royaume-Uni s'écrit `GB` dans une locale et `uk` dans notre table.
    if (region === "gb") return "uk";
  }
  return FALLBACK_COUNTRY;
}

function regionOf(locale: string): string | null {
  const parts = locale.split("-");
  const last = parts[parts.length - 1];
  return last && last.length === 2 ? last.toLowerCase() : null;
}
