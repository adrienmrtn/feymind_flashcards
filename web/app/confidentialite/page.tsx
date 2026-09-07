import type { Metadata } from "next";

import { PrivacyDoc } from "@/components/legal/PrivacyDoc";
import { indexableAlternates } from "@/lib/i18n/alternates";
import { getTranslator } from "@/lib/i18n/server";
import { PRIVACY_PATH } from "@/lib/legal";

export async function generateMetadata(): Promise<Metadata> {
  const { t, locale } = await getTranslator();
  return {
    title: t("legal.privacy.metaTitle"),
    description: t("legal.privacy.metaDescription"),
    alternates: indexableAlternates(locale, PRIVACY_PATH),
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
