"use client";

import { createContext, useContext, useEffect, useMemo, useRef, useState } from "react";

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
  /// Locale posée par le sélecteur, en attendant que le cookie suive.
  const pending = useRef<UiLocale | null>(null);

  useEffect(() => {
    // `revalidatePath` dans l'action relit encore le cookie de la requête :
    // sans ce garde, le serveur rétablit l'ancienne langue par-dessus le choix.
    if (pending.current && locale !== pending.current) return;
    pending.current = null;
    setCurrent(locale);
  }, [locale, messages]);

  const value = useMemo(() => {
    function pick(next: UiLocale) {
      if (next === current) return;
      pending.current = next;
      setCurrent(next);
      document.documentElement.lang = UI_LOCALE_META[next].html;
    }

    return {
      locale: current,
      t: makeTranslator(
        current,
        catalogFor(current) as unknown as MessageTree,
        fr as unknown as MessageTree,
      ),
      pick,
    };
  }, [current]);

  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n() {
  const ctx = useContext(I18nContext);
  if (!ctx) {
    throw new Error("useI18n must sit inside I18nProvider");
  }
  return ctx;
}
