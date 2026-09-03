import type { Metadata } from "next";

import { TermsDoc } from "@/components/legal/TermsDoc";
import { getTranslator } from "@/lib/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  const { t } = await getTranslator();
  return {
    title: t("legal.terms.metaTitle"),
    description: t("legal.terms.metaDescription"),
    alternates: { canonical: "/conditions" },
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
