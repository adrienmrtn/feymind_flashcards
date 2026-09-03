"use client";

import { LegalList, LegalP, legalVars } from "@/components/legal/LegalMarkup";
import { LegalSection, LegalShell } from "@/components/legal/LegalShell";
import { useI18n } from "@/lib/i18n/client";

export function PrivacyDoc() {
  const { t } = useI18n();
  const vars = legalVars();

  return (
    <LegalShell title={t("legal.privacy.heading")}>
      <LegalP k="legal.privacy.intro1" vars={vars} />
      <LegalP k="legal.privacy.intro2" vars={vars} />

      <LegalSection title={t("legal.privacy.whatTitle")}>
        <LegalP k="legal.privacy.whatBody" />
      </LegalSection>

      <LegalSection title={t("legal.privacy.dataTitle")}>
        <LegalP k="legal.privacy.dataAccount" />
        <LegalP k="legal.privacy.dataSchool" />
        <LegalP k="legal.privacy.dataCourses" />
        <LegalP k="legal.privacy.dataFriends" />
        <LegalP k="legal.privacy.dataSubscription" />
        <LegalP k="legal.privacy.dataWaitlist" />
        <LegalP k="legal.privacy.dataFeedback" />
        <LegalP k="legal.privacy.dataUsage" />
        <LegalP k="legal.privacy.dataDirectory" />
        <LegalP k="legal.privacy.dataDevice" />
        <LegalP k="legal.privacy.dataNoSell" />
      </LegalSection>

      <LegalSection title={t("legal.privacy.whyTitle")}>
        <LegalP k="legal.privacy.whyLead" />
        <LegalList
          keys={[
            "legal.privacy.whyContract",
            "legal.privacy.whyLegitimate",
            "legal.privacy.whyLegal",
            "legal.privacy.whyConsent",
          ]}
        />
      </LegalSection>

      <LegalSection title={t("legal.privacy.accessTitle")}>
        <LegalP k="legal.privacy.accessBody" />
        <LegalP k="legal.privacy.accessLead" />
        <LegalList
          keys={[
            "legal.privacy.accessSupabase",
            "legal.privacy.accessVercel",
            "legal.privacy.accessApple",
            "legal.privacy.accessStripe",
            "legal.privacy.accessRevenuecat",
            "legal.privacy.accessFal",
            "legal.privacy.accessYoutube",
          ]}
        />
        <LegalP k="legal.privacy.accessTransfer" />
      </LegalSection>

      <LegalSection title={t("legal.privacy.cookiesTitle")}>
        <LegalP k="legal.privacy.cookiesWeb" />
        <LegalP k="legal.privacy.cookiesIos" />
      </LegalSection>

      <LegalSection title={t("legal.privacy.retentionTitle")}>
        <LegalP k="legal.privacy.retentionWhile" />
        <LegalP k="legal.privacy.retentionShared" />
        <LegalP k="legal.privacy.retentionAfter" />
      </LegalSection>

      <LegalSection title={t("legal.privacy.rightsTitle")}>
        <LegalP k="legal.privacy.rightsBody" />
        <LegalP k="legal.privacy.rightsCnil" />
      </LegalSection>

      <LegalSection title={t("legal.privacy.minorsTitle")}>
        <LegalP k="legal.privacy.minorsBody" />
      </LegalSection>

      <LegalSection title={t("legal.privacy.iosTitle")}>
        <LegalP k="legal.privacy.iosBody" />
      </LegalSection>

      <LegalSection title={t("legal.privacy.changesTitle")}>
        <LegalP k="legal.privacy.changesBody" />
        <LegalP k="legal.privacy.changesAlso" />
      </LegalSection>
    </LegalShell>
  );
}
