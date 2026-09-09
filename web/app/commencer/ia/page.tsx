"use client";

import { StoryScaffold } from "@/components/onboarding/Scaffold";
import { AiStory } from "@/components/onboarding/stories/AiStory";
import { useI18n } from "@/lib/i18n/client";

/** Les quatre façons dont Micabo interroge : examen blanc, QCM, carte, texte à trou. */
export default function AiStep() {
  const { t } = useI18n();
  return (
    <StoryScaffold
      title={
        <>
          {t("onboarding.iaTitleLead")}{" "}
          <span className="text-accent">{t("onboarding.iaTitleStrong")}</span>
        </>
      }
      lead={t("onboarding.iaLead")}
    >
      <AiStory />
    </StoryScaffold>
  );
}
