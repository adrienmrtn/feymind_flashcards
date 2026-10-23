"use client";

import { createContext, useContext, useEffect, useMemo, useRef, useState } from "react";

import type { MessageTree } from "./format";
import { en } from "./catalogs/en";
import { UI_LOCALE_META, type UiLocale } from "./locales";
import { makeTranslator } from "./translate";

type Translator = ReturnType<typeof makeTranslator>;

const I18nContext = createContext<{
  locale: UiLocale;
  t: Translator;
  pick: (next: UiLocale) => void;
} | null>(null);

/** Pose la langue et le sens de lecture sur `<html>`, comme le fait le layout au rendu. */
function applyDocumentLocale(locale: UiLocale) {
  const meta = UI_LOCALE_META[locale];
  document.documentElement.lang = meta.html;
  document.documentElement.dir = meta.dir;
}

/**
 * **Un seul catalogue dans le navigateur** : celui de la page, que le layout passe en
 * `messages`, plus l'anglais pour les clés absentes.
 *
 * Les vingt-six catalogues importés ici partaient tous dans le JavaScript de chaque page —
 * plusieurs centaines de kilo-octets pour une langue lue à la fois. Le sélecteur, lui, charge
 * le catalogue choisi à la demande (`import()`), le temps que le serveur renvoie la page dans
 * la nouvelle langue.
 */
export function I18nProvider({
  locale,
  messages,
  children,
}: {
  locale: UiLocale;
  messages: MessageTree;
  children: React.ReactNode;
}) {
  const [current, setCurrent] = useState<{ locale: UiLocale; messages: MessageTree }>({
    locale,
    messages,
  });
  /// Locale posée par le sélecteur, en attendant que le cookie suive.
  const pending = useRef<UiLocale | null>(null);

  useEffect(() => {
    // `revalidatePath` dans l'action relit encore le cookie de la requête :
    // sans ce garde, le serveur rétablit l'ancienne langue par-dessus le choix.
    if (pending.current && locale !== pending.current) return;
    pending.current = null;
    // Un `router.refresh` renvoie le même catalogue sous un nouvel objet : ne rien repeindre
    // tant que la langue ne change pas.
    setCurrent((prev) => (prev.locale === locale ? prev : { locale, messages }));
  }, [locale, messages]);

  const value = useMemo(() => {
    function pick(next: UiLocale) {
      if (next === current.locale) return;
      pending.current = next;
      applyDocumentLocale(next);
      void import("./catalogs").then(({ catalogFor }) => {
        // Un autre choix, ou la page du serveur, est passé entre-temps.
        if (pending.current !== next) return;
        setCurrent({ locale: next, messages: catalogFor(next) as unknown as MessageTree });
      });
    }

    return {
      locale: current.locale,
      t: makeTranslator(current.locale, current.messages, en as unknown as MessageTree),
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
