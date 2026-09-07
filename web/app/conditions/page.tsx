import type { Metadata } from "next";

import { TermsDoc } from "@/components/legal/TermsDoc";
import { indexableAlternates } from "@/lib/i18n/alternates";
import { getTranslator } from "@/lib/i18n/server";
import { TERMS_PATH } from "@/lib/legal";

export async function generateMetadata(): Promise<Metadata> {
  const { t, locale } = await getTranslator();
  return {
    title: t("legal.terms.metaTitle"),
    description: t("legal.terms.metaDescription"),
    alternates: indexableAlternates(locale, TERMS_PATH),
  };
}

/**
 * Les conditions, pour les deux clients.
 *
 * Même adresse que le paywall iOS : `https://micabo.app/conditions`.
 */
export default function TermsPage() {
  return <TermsDoc />;
}
