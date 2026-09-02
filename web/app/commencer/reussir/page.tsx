"use client";

import { ExamPrepStory } from "@/components/onboarding/ExamPrepStory";
import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";
import { useI18n } from "@/lib/i18n/client";

/**
 * Le jour J, et les cartes qui s'y rendent.
 */
export default function ExamPrepStep() {
  const { t } = useI18n();
  return (
    <Scaffold
      title={t("onboarding.reussirTitle")}
      footer={<ContinueButton enabled href="/commencer/retention" />}
      center
    >
      <ExamPrepStory />
    </Scaffold>
  );
}
