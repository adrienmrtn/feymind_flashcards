import { cache } from "react";
import { cookies, headers } from "next/headers";

import { catalogFor } from "./catalogs";
import { fr } from "./catalogs/fr";
import {
  DEFAULT_UI_LOCALE,
  UI_LOCALE_COOKIE,
  isUiLocale,
  localeFromAcceptLanguage,
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
  const fromUrl = (await headers()).get(LOCALE_HEADER);
  if (isUiLocale(fromUrl)) return fromUrl;
  const store = await cookies();
  const fromCookie = store.get(UI_LOCALE_COOKIE)?.value;
  if (isUiLocale(fromCookie)) return fromCookie;
  const accept = (await headers()).get("accept-language");
  return localeFromAcceptLanguage(accept) ?? DEFAULT_UI_LOCALE;
});

export const getTranslator = cache(async () => {
  const locale = await readUiLocale();
  const messages = catalogFor(locale) as unknown as MessageTree;
  const fallback = fr as unknown as MessageTree;
  return { locale, t: makeTranslator(locale, messages, fallback), messages };
});
