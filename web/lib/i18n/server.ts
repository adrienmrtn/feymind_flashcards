import { cache } from "react";
import { cookies, headers } from "next/headers";

import { catalogFor } from "./catalogs";
import { en } from "./catalogs/en";
import {
  DEFAULT_UI_LOCALE,
  UI_LOCALE_COOKIE,
  isUiLocale,
  matchAcceptLanguage,
  type UiLocale,
} from "./locales";
import { LOCALE_HEADER } from "./paths";
import { makeTranslator } from "./translate";
import type { MessageTree } from "./format";

/**
 * Deux régimes.
 *
 * 1. Page **indexable** : le middleware a posé `x-micabo-locale`. C'est
 *    l'URL qui décide, cookie et `Accept-Language` ignorés — sinon le robot
 *    et le visiteur ne voient pas la même chose.
 * 2. Page **privée** (`/app`, `/commencer`) : pas de header, le cookie puis
 *    le navigateur, comme avant.
 */
export const readUiLocale = cache(async (): Promise<UiLocale> => {
  const { chosen, navigator } = await readLocaleSignals();
  return chosen ?? navigator ?? DEFAULT_UI_LOCALE;
});

/**
 * **Ce que la requête dit vraiment de la langue**, avant qu'on tranche.
 *
 * `readUiLocale` doit rendre une langue : une page s'affiche toujours dans quelque chose.
 * Mais ce faisant elle écrase la différence entre « anglais choisi » et « anglais faute de
 * mieux » — et c'est précisément celle dont la page de paiement a besoin pour aller chercher
 * le pays plutôt que de servir un checkout anglais à un étudiant turc.
 */
export const readLocaleSignals = cache(
  async (): Promise<{ chosen: UiLocale | null; navigator: UiLocale | null }> => {
    const head = await headers();
    const fromUrl = head.get(LOCALE_HEADER);
    if (isUiLocale(fromUrl)) return { chosen: fromUrl, navigator: null };

    const store = await cookies();
    const fromCookie = store.get(UI_LOCALE_COOKIE)?.value;
    const chosen = isUiLocale(fromCookie) ? fromCookie : null;
    return { chosen, navigator: matchAcceptLanguage(head.get("accept-language")) };
  },
);

/** Un traducteur dans une langue **dite**, quand ce n'est pas celle de la page. */
export function translatorFor(locale: UiLocale) {
  return makeTranslator(
    locale,
    catalogFor(locale) as unknown as MessageTree,
    en as unknown as MessageTree,
  );
}

export const getTranslator = cache(async () => {
  const locale = await readUiLocale();
  const messages = catalogFor(locale) as unknown as MessageTree;
  const fallback = en as unknown as MessageTree;
  return { locale, t: makeTranslator(locale, messages, fallback), messages };
});
