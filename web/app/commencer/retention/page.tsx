"use client";

import { RetentionStory } from "@/components/onboarding/RetentionStory";
import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";
import { useI18n } from "@/lib/i18n/client";

/**
 * Pourquoi la répétition espacée gagne — montré, pas affirmé.
 */
export default function RetentionStep() {
  const { t } = useI18n();
  return (
    <Scaffold
      title={t("onboarding.retentionTitle")}
      footer={<ContinueButton enabled href="/commencer/personnaliser" />}
    >
      <RetentionStory />
    </Scaffold>
  );
}
