"use client";

import { StoryScaffold } from "@/components/onboarding/Scaffold";
import { FormatsStory } from "@/components/onboarding/stories/FormatsStory";
import { useI18n } from "@/lib/i18n/client";

/** Ce qu'on apporte, et ce que Micabo accepte : tout ce qui traîne autour d'un examen. */
export default function ImportStep() {
  const { t } = useI18n();
  return (
    <StoryScaffold
      title={
        <>
          {t("onboarding.importerTitleLead")}{" "}
          <span className="text-accent">{t("onboarding.importerTitleStrong")}</span>
        </>
      }
      lead={t("onboarding.importerLead")}
      next="/commencer/plan"
    >
      <FormatsStory />
    </StoryScaffold>
  );
}
