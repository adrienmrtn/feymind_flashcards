"use client";

import { StoryScaffold } from "@/components/onboarding/Scaffold";
import { MikaWritesStory } from "@/components/onboarding/stories/MikaWritesStory";
import { useI18n } from "@/lib/i18n/client";

/** Qui écrit : Mika, les notes thème par thème, puis les quiz et les flashcards. */
export default function MikaStep() {
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
      <MikaWritesStory />
    </StoryScaffold>
  );
}
