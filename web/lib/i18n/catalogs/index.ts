import type { Catalog } from "./fr";
import { en } from "./en";
import { fr } from "./fr";
import { de } from "./de";
import { es } from "./es";
import { tr } from "./tr";
import { DEFAULT_UI_LOCALE, UI_LOCALES, type UiLocale } from "../locales";
import { es419 } from "./es-419";
import { nl } from "./nl";
import { ro } from "./ro";
import { it } from "./it";
import { pt } from "./pt";
import { ptBR } from "./pt-br";
import { pl } from "./pl";
import { cs } from "./cs";
import { sk } from "./sk";
import { sv } from "./sv";
import { da } from "./da";
import { fi } from "./fi";

export { en, fr, de, es, tr };
export type { Catalog };

/**
 * Un catalogue par langue.
 *
 * **Une langue sans traduction pointe sur l'anglais**, l'objet lui-même (`it: en`) : le site
 * s'affiche, et `isTranslatedLocale` sait la reconnaître pour la tenir hors du sitemap et des
 * `hreflang` — une page anglaise servie sous `/it` serait un doublon, pas une traduction.
 *
 * Brancher une traduction : `import { it } from "./it";` en tête, puis `it,` à la place de
 * `it: en, // TODO(traduction)` ci-dessous. Les clés manquantes retombent sur l'anglais
 * (`makeTranslator`), mais `Catalog` les exige toutes.
 */
export const CATALOGS: Record<UiLocale, Catalog> = {
  en,
  fr,
  de,
  es,
  "es-419": es419,
  it: it,
  pt: pt,
  "pt-BR": ptBR,
  nl: nl,
  pl: pl,
  ro: ro,
  sv: sv,
  da: da,
  fi: fi,
  et: en, // TODO(traduction) : import { et } from "./et";
  cs: cs,
  sk: sk,
  hu: en, // TODO(traduction) : import { hu } from "./hu";
  hr: en, // TODO(traduction) : import { hr } from "./hr";
  sl: en, // TODO(traduction) : import { sl } from "./sl";
  sr: en, // TODO(traduction) : import { sr } from "./sr";
  bg: en, // TODO(traduction) : import { bg } from "./bg";
  el: en, // TODO(traduction) : import { el } from "./el";
  ru: en, // TODO(traduction) : import { ru } from "./ru";
  tr,
  ar: en, // TODO(traduction) : import { ar } from "./ar";
};

export function catalogFor(locale: UiLocale): Catalog {
  return CATALOGS[locale] ?? en;
}

/** La langue a-t-elle son propre catalogue, ou n'est-elle encore que l'anglais ? */
export function isTranslatedLocale(locale: UiLocale): boolean {
  return locale === DEFAULT_UI_LOCALE || CATALOGS[locale] !== en;
}

/** Les langues réellement traduites, dans l'ordre d'`UI_LOCALES`. */
export const TRANSLATED_UI_LOCALES: readonly UiLocale[] = UI_LOCALES.filter(isTranslatedLocale);
