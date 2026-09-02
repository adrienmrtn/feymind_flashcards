import { formatMessage, lookup, type MessageTree } from "./format";
import type { UiLocale } from "./locales";

export function makeTranslator(locale: UiLocale, messages: MessageTree, fallback: MessageTree) {
  return function t(path: string, vars?: Record<string, string | number>): string {
    const template = lookup(messages, path) ?? lookup(fallback, path) ?? path;
    return formatMessage(template, vars, locale);
  };
}
