import { formatMessage, lookup, type MessageTree } from "./format";
import { UI_LOCALE_META, type UiLocale } from "./locales";

/**
 * `t(clé, variables)` dans une langue, l'anglais (ou `fallback`) pour les clés absentes.
 *
 * Pluriels et nombres se forment avec la locale `Intl` de la langue (`bcp47`) : `pt-BR`,
 * `sr-Latn-RS`, `ar-AE` — pas le code du cookie.
 */
export function makeTranslator(locale: UiLocale, messages: MessageTree, fallback: MessageTree) {
  const intl = UI_LOCALE_META[locale]?.bcp47 ?? locale;
  return function t(path: string, vars?: Record<string, string | number>): string {
    const template = lookup(messages, path) ?? lookup(fallback, path) ?? path;
    return formatMessage(template, vars, intl);
  };
}
