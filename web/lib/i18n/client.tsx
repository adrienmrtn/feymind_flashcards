"use client";

import { createContext, useContext, useEffect, useMemo, useState } from "react";

import { catalogFor } from "./catalogs";
import type { MessageTree } from "./format";
import { fr } from "./catalogs/fr";
import { UI_LOCALE_META, type UiLocale } from "./locales";
import { makeTranslator } from "./translate";

type Translator = ReturnType<typeof makeTranslator>;

const I18nContext = createContext<{
  locale: UiLocale;
  t: Translator;
  pick: (next: UiLocale) => void;
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
  const [current, setCurrent] = useState(locale);
  const [tree, setTree] = useState(messages);

  useEffect(() => {
    setCurrent(locale);
    setTree(messages);
  }, [locale, messages]);

  const value = useMemo(() => {
    function pick(next: UiLocale) {
      if (next === current) return;
      setCurrent(next);
      setTree(catalogFor(next) as unknown as MessageTree);
      document.documentElement.lang = UI_LOCALE_META[next].html;
    }

    return {
      locale: current,
      t: makeTranslator(current, tree, fr as unknown as MessageTree),
      pick,
    };
  }, [current, tree]);

  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n() {
  const ctx = useContext(I18nContext);
  if (!ctx) {
    throw new Error("useI18n must sit inside I18nProvider");
  }
  return ctx;
}
