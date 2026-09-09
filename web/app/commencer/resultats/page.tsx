"use client";

import { StoryScaffold } from "@/components/onboarding/Scaffold";
import { ResultsStory } from "@/components/onboarding/stories/ResultsStory";
import { useI18n } from "@/lib/i18n/client";

/** Le dernier écran de démonstration : ce que ça change sur le bulletin. */
export default function ResultsStep() {
  const { t } = useI18n();
  return (
    <StoryScaffold
      title={
        <>
          {t("onboarding.resultatsTitleLead")}{" "}
          <span className="text-accent">{t("onboarding.resultatsTitleStrong")}</span>{" "}
          {t("onboarding.resultatsTitleTail")}
        </>
      }
      lead={t("onboarding.resultatsLead")}
      next="/commencer/personnaliser"
    >
      <ResultsStory />
    </StoryScaffold>
  );
}
