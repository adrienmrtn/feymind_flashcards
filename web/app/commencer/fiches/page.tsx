"use client";

import { SheetStory } from "@/components/onboarding/SheetStory";
import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";
import { useI18n } from "@/lib/i18n/client";

/**
 * Ce qui sort de l'import : des fiches, montrées telles qu'elles sont écrites.
 */
export default function SheetsStep() {
  const { t } = useI18n();
  return (
    <Scaffold
      title={t("onboarding.fichesTitle")}
      footer={<ContinueButton enabled href="/commencer/cartes" />}
    >
      <SheetStory />
    </Scaffold>
  );
}
