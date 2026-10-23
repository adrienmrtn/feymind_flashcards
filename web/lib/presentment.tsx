"use client";

import { createContext, useContext, type ReactNode } from "react";

import type { pricing } from "@micabo/core";

import { useI18n } from "@/lib/i18n/client";
import { presentmentFor } from "@/lib/pricing-copy";

/**
 * **Le pays dont on affiche les prix**, résolu une fois côté serveur (`readPricingCountry` :
 * le compte, puis l'adresse IP, puis le navigateur) et lu par chaque paywall.
 *
 * `startCheckout` résout le même pays de la même manière. Sans ce contexte, le paywall ne
 * verrait que la langue : un Espagnol lirait 49,99 € pendant que l'app lui vend 39,99 €, et
 * un Turc en interface française verrait des € avant de payer en ₺.
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

/** Les prix du pays du lecteur, écrits dans la langue du site. */
export function usePresentment(): pricing.Presentment {
  const country = useContext(CountryContext);
  const { locale } = useI18n();
  return presentmentFor(locale, country);
}
