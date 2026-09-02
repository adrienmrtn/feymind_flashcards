"use client";

import { ImportStory } from "@/components/onboarding/ImportStory";
import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";
import { useI18n } from "@/lib/i18n/client";

/**
 * Comment un document devient une fiche, montré plutôt que raconté.
 */
export default function ImportStep() {
  const { t } = useI18n();
  return (
    <Scaffold
      title={t("onboarding.importTitle")}
      footer={<ContinueButton enabled href="/commencer/fiches" />}
      center
    >
      <ImportStory />
    </Scaffold>
  );
}
