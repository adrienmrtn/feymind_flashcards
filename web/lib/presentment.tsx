"use client";

import { createContext, useContext, type ReactNode } from "react";

import type { pricing } from "@micabo/core";

import { useI18n } from "@/lib/i18n/client";
import { presentmentFor } from "@/lib/pricing-copy";

/**
 * Le pays de scolarisation, pour que l'affichage et l'encaissement
 * parlent la même devise.
 *
 * `startCheckout` lit `profiles.country_code`. Sans ce contexte, le paywall
 * ne verrait que la langue : un Turc en interface française verrait des €
 * et paierait en ₺.
 */

const CountryContext = createContext<string | null | undefined>(undefined);

export function PresentmentProvider({
  country,
  children,
}: {
  country?: string | null;
  children: ReactNode;
}) {
  return <CountryContext.Provider value={country ?? null}>{children}</CountryContext.Provider>;
}

export function usePresentment(): pricing.PresentmentCurrency {
  const country = useContext(CountryContext);
  const { locale } = useI18n();
  return presentmentFor(locale, country);
}
