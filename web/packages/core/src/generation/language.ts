/**
 * La langue de **cette** génération.
 *
 * Ce n'est pas la langue du profil. Le profil dit comment on écrit d'habitude ;
 * ici on tranche pour le document qu'on a sous les yeux. Par défaut on reste
 * dans la langue du cours. On ne force une autre langue que si on le demande.
 */

import {
  CONTENT_LANGUAGES,
  LANGUAGE_LABELS,
  isContentLanguage,
  type ContentLanguage,
} from "../onboarding/countries";

/** Le modèle écrit dans la langue du document, sans traduction. */
export const SOURCE_LANGUAGE = "source" as const;

export type GenerationLanguage = typeof SOURCE_LANGUAGE | ContentLanguage;

export const GENERATION_LANGUAGES: readonly GenerationLanguage[] = [
  SOURCE_LANGUAGE,
  ...CONTENT_LANGUAGES,
];

export function isGenerationLanguage(
  value: string | null | undefined,
): value is GenerationLanguage {
  return value === SOURCE_LANGUAGE || isContentLanguage(value);
}

export function generationLanguageLabel(value: GenerationLanguage): string {
  return value === SOURCE_LANGUAGE ? "Langue du document" : LANGUAGE_LABELS[value];
}
