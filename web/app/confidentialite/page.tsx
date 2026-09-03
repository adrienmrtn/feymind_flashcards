import type { Metadata } from "next";

import { PrivacyDoc } from "@/components/legal/PrivacyDoc";
import { getTranslator } from "@/lib/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  const { t } = await getTranslator();
  return {
    title: t("legal.privacy.metaTitle"),
    description: t("legal.privacy.metaDescription"),
    alternates: { canonical: "/confidentialite" },
  };
}

/**
 * La politique de confidentialité, pour les deux clients.
 *
 * Les adresses sont celles que l'app iOS ouvre déjà depuis le paywall
 * (`https://micabo.app/confidentialite`).
 */
export default function PrivacyPage() {
  return <PrivacyDoc />;
}
