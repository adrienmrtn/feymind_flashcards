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
export type ContentLanguage = "fr" | "en";

const DEFAULT_LANGUAGE: ContentLanguage = "fr";

const SUPPORTED: readonly ContentLanguage[] = ["fr", "en"];

/** Le nom de la langue, écrit en français, pour les consignes du modèle. */
const NAMES: Record<ContentLanguage, string> = {
  fr: "français",
  en: "anglais",
};

const BRIEFS: Record<ContentLanguage, string> = {
  fr:
    `LANGUE DE SORTIE : FRANÇAIS. Tout ce que tu écris est en français, y compris les titres, les légendes et les intitulés.`,
  en:
    `LANGUE DE SORTIE : ANGLAIS. Cette consigne est la plus forte de toutes et elle l'emporte sur toute mention du français ailleurs dans les instructions. Tout ce que tu produis est rédigé en ANGLAIS : titres, paragraphes, définitions, intitulés de colonnes, légendes, questions et réponses. Les règles de rédaction, de structure et de mise en forme restent celles décrites plus haut, à la lettre ; seule la langue change. Les termes techniques gardent leur forme anglaise usuelle, et un terme cité dans une autre langue reste dans la sienne. Tu n'écris pas une traduction du français : tu écris directement en anglais, avec le vocabulaire que l'examen attend dans ce pays.`,
};

/** La langue demandée, ou le français quand la demande est absente ou inconnue. */
export function resolveLanguage(code: string | undefined): ContentLanguage {
  const cleaned = (code ?? "").trim().toLowerCase().slice(0, 2);
  return SUPPORTED.includes(cleaned as ContentLanguage)
    ? cleaned as ContentLanguage
    : DEFAULT_LANGUAGE;
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
  return BRIEFS[resolveLanguage(code)];
}
