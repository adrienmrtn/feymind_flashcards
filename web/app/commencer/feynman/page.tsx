"use client";

import { StoryScaffold } from "@/components/onboarding/Scaffold";
import { QuizStory } from "@/components/onboarding/stories/QuizStory";
import { useI18n } from "@/lib/i18n/client";

/** Comment on apprend : on répond, la leçon dit si c'est juste et pourquoi. */
export default function QuizStep() {
  const { t } = useI18n();
  return (
    <StoryScaffold
      title={
        <>
          {t("onboarding.quizTitleLead")}{" "}
          <span className="text-accent">{t("onboarding.quizTitleStrong")}</span>
        </>
      }
      lead={t("onboarding.quizLead")}
    >
      <QuizStory />
    </StoryScaffold>
  );
}
