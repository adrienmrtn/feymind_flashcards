"use client";

import { LegalList, LegalP, legalVars } from "@/components/legal/LegalMarkup";
import { LegalSection, LegalShell } from "@/components/legal/LegalShell";
import { useI18n } from "@/lib/i18n/client";

export function TermsDoc() {
  const { t } = useI18n();
  const vars = legalVars();

  return (
    <LegalShell title={t("legal.terms.heading")}>
      <LegalP k="legal.terms.intro1" vars={vars} />
      <LegalP k="legal.terms.intro2" vars={vars} />

      <LegalSection title={t("legal.terms.serviceTitle")}>
        <LegalP k="legal.terms.serviceBody" />
        <LegalP k="legal.terms.servicePro" />
      </LegalSection>

      <LegalSection title={t("legal.terms.accountTitle")}>
        <LegalP k="legal.terms.accountBody" />
        <LegalP k="legal.terms.accountDelete" />
      </LegalSection>

      <LegalSection title={t("legal.terms.coursesTitle")}>
        <LegalP k="legal.terms.coursesOwn" />
        <LegalP k="legal.terms.coursesRights" />
        <LegalP k="legal.terms.coursesShare" />
      </LegalSection>

      <LegalSection title={t("legal.terms.notTitle")}>
        <LegalP k="legal.terms.notBody" />
        <LegalP k="legal.terms.notInvent" />
      </LegalSection>

      <LegalSection title={t("legal.terms.subTitle")}>
        <LegalP k="legal.terms.subPrices" />
        <LegalP k="legal.terms.subIos" />
        <LegalP k="legal.terms.subWeb" />
        <LegalP k="legal.terms.subBoth" />
      </LegalSection>

      <LegalSection title={t("legal.terms.forbidTitle")}>
        <LegalList
          keys={[
            "legal.terms.forbidHarm",
            "legal.terms.forbidAccess",
            "legal.terms.forbidResell",
            "legal.terms.forbidIllegal",
          ]}
        />
      </LegalSection>

      <LegalSection title={t("legal.terms.availTitle")}>
        <LegalP k="legal.terms.availBody" />
      </LegalSection>

      <LegalSection title={t("legal.terms.liabilityTitle")}>
        <LegalP k="legal.terms.liabilityConsumer" />
        <LegalP k="legal.terms.liabilityLimit" />
      </LegalSection>

      <LegalSection title={t("legal.terms.minorsTitle")}>
        <LegalP k="legal.terms.minorsBody" />
      </LegalSection>

      <LegalSection title={t("legal.terms.lawTitle")}>
        <LegalP k="legal.terms.lawBody" />
      </LegalSection>

      <LegalSection title={t("legal.terms.changesTitle")}>
        <LegalP k="legal.terms.changesBody" />
        <LegalP k="legal.terms.changesAlso" />
      </LegalSection>
    </LegalShell>
  );
}
