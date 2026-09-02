"use client";

import { createContext, useContext, useMemo } from "react";

import type { MessageTree } from "./format";
import { fr } from "./catalogs/fr";
import type { UiLocale } from "./locales";
import { makeTranslator } from "./translate";

type Translator = ReturnType<typeof makeTranslator>;

const I18nContext = createContext<{
  locale: UiLocale;
  t: Translator;
} | null>(null);

export function I18nProvider({
  locale,
  messages,
  children,
}: {
  locale: UiLocale;
  messages: MessageTree;
  children: React.ReactNode;
}) {
  const value = useMemo(
    () => ({
      locale,
      t: makeTranslator(locale, messages, fr as unknown as MessageTree),
    }),
    [locale, messages],
  );

  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n() {
  const ctx = useContext(I18nContext);
  if (!ctx) {
    throw new Error("useI18n must sit inside I18nProvider");
  }
  return ctx;
}
