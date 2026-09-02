"use client";

import { FlashcardStory } from "@/components/onboarding/FlashcardStory";
import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";
import { useI18n } from "@/lib/i18n/client";

/**
 * Une session, en petit : on répond, on se note, la carte revient.
 */
export default function CardsIntroStep() {
  const { t } = useI18n();
  return (
    <Scaffold
      title={t("onboarding.cartesTitle")}
      footer={<ContinueButton enabled href="/commencer/reussir" />}
      center
    >
      <FlashcardStory />
    </Scaffold>
  );
}
