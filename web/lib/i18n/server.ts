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
import { makeTranslator } from "./translate";
import type { MessageTree } from "./format";

export const readUiLocale = cache(async (): Promise<UiLocale> => {
  const store = await cookies();
  const fromCookie = store.get(UI_LOCALE_COOKIE)?.value;
  if (isUiLocale(fromCookie)) return fromCookie;
  const accept = (await headers()).get("accept-language");
  return localeFromAcceptLanguage(accept);
});

export const getTranslator = cache(async () => {
  const locale = await readUiLocale();
  const messages = catalogFor(locale) as unknown as MessageTree;
  const fallback = fr as unknown as MessageTree;
  return { locale, t: makeTranslator(locale, messages, fallback), messages };
});
