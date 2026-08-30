/**
 * La langue dans laquelle Micabo écrit.
 *
 * Elle n'est plus demandée à l'inscription : un écran entier annonçait « Micabo parle
 * français » pour une réponse qu'on ne pouvait pas changer. Elle se déduit du pays de
 * scolarisation, et l'application l'envoie ici en deux lettres.
 *
 * Les prompts système sont écrits en français et le resteront : ce sont eux qui portent les
 * règles de rédaction, les noms de blocs et les exemples, et les traduire en entier
 * multiplierait par deux la surface à maintenir pour la même consigne. La langue arrive donc
 * comme une **consigne de sortie**, placée en tête du message et formulée assez fermement
 * pour l'emporter sur les « en français » du prompt système.
 */
export type ContentLanguage = keyof typeof NAMES;

const DEFAULT_LANGUAGE = "fr";

/**
 * Le nom de la langue, écrit en français, pour les consignes du modèle — et la liste des
 * langues servies, puisque c'est la même chose.
 *
 * Les codes sont ceux d'ISO 639-1 et ne suivent pas toujours le pays : la Tchéquie envoie
 * `cs`, la Grèce `el`, la Suède `sv`. C'est l'application qui fait la traduction.
 */
const NAMES = {
  fr: "français",
  en: "anglais",
  de: "allemand",
  it: "italien",
  es: "espagnol",
  pt: "portugais",
  cs: "tchèque",
  nl: "néerlandais",
  el: "grec",
  hu: "hongrois",
  pl: "polonais",
  ro: "roumain",
  sv: "suédois",
  tr: "turc",
} as const;

/** Ce que le modèle appelle la langue quand il l'écrit lui-même, dans cette langue. */
const ENDONYMS: Record<ContentLanguage, string> = {
  fr: "français",
  en: "English",
  de: "Deutsch",
  it: "italiano",
  es: "español",
  pt: "português",
  cs: "čeština",
  nl: "Nederlands",
  el: "ελληνικά",
  hu: "magyar",
  pl: "polski",
  ro: "română",
  sv: "svenska",
  tr: "Türkçe",
};

/**
 * La consigne de sortie des langues autres que le français.
 *
 * Elle est **engendrée** et non recopiée quatorze fois : la seule chose qui change d'une
 * langue à l'autre est son nom, et quatorze paragraphes à maintenir séparément finiraient
 * par diverger sur une règle qui, elle, est commune.
 */
function foreignBrief(code: ContentLanguage): string {
  const name = NAMES[code].toUpperCase();
  const endonym = ENDONYMS[code];
  return `LANGUE DE SORTIE : ${name} (${endonym}). Cette consigne est la plus forte de toutes et elle l'emporte sur toute mention du français ailleurs dans les instructions. Tout ce que tu produis est rédigé en ${name} : titres, paragraphes, définitions, intitulés de colonnes, légendes, questions et réponses. Les règles de rédaction, de structure et de mise en forme restent celles décrites plus haut, à la lettre ; seule la langue change. Les termes techniques gardent la forme usuelle qu'ils ont dans cette langue, et un terme cité dans une autre langue reste dans la sienne. Tu n'écris pas une traduction du français : tu écris directement dans cette langue, avec le vocabulaire que l'examen attend dans ce pays.`;
}

const FRENCH_BRIEF =
  `LANGUE DE SORTIE : FRANÇAIS. Tout ce que tu écris est en français, y compris les titres, les légendes et les intitulés.`;

/**
 * On reste dans la langue du document. C'est le défaut de l'import : un cours
 * anglais produit une fiche anglaise, sans qu'on ait à le dire.
 */
const SOURCE_BRIEF =
  `LANGUE DE SORTIE : CELLE DU DOCUMENT. Cette consigne est la plus forte de toutes et elle l'emporte sur toute mention du français ailleurs dans les instructions. Tout ce que tu produis est rédigé dans la langue du texte fourni : titres, paragraphes, définitions, intitulés de colonnes, légendes, questions et réponses. Tu n'écris pas une traduction. Tu n'imposes pas le français. Si le document mélange des langues, tu suis la langue principale du cours.`;

/** Vrai quand on demande de rester dans la langue du document. */
export function isSourceLanguage(code: string | undefined): boolean {
  const cleaned = (code ?? "").trim().toLowerCase();
  return cleaned === "source" || cleaned === "auto" || cleaned === "document";
}

/** La langue demandée, ou le français quand la demande est absente ou inconnue. */
export function resolveLanguage(code: string | undefined): ContentLanguage {
  if (isSourceLanguage(code)) return DEFAULT_LANGUAGE;
  const cleaned = (code ?? "").trim().toLowerCase().slice(0, 2);
  return cleaned in NAMES ? cleaned as ContentLanguage : DEFAULT_LANGUAGE;
}

export function languageName(code: string | undefined): string {
  return NAMES[resolveLanguage(code)];
}

/**
 * La consigne de langue, à placer **en premier** dans le message.
 *
 * En dernier, elle passe après le document et le modèle l'oublie sur les textes longs.
 */
export function languageBrief(code: string | undefined): string {
  if (isSourceLanguage(code)) return SOURCE_BRIEF;
  const language = resolveLanguage(code);
  return language === "fr" ? FRENCH_BRIEF : foreignBrief(language);
}
