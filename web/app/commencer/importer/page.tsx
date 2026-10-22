"use client";

import { StoryScaffold } from "@/components/onboarding/Scaffold";
import { SupportsStory } from "@/components/onboarding/stories/SupportsStory";
import { useI18n } from "@/lib/i18n/client";

/** Ce qu'on apporte : un sujet tapé, ou un des cinq supports de la barre de Home. */
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
    >
      <SupportsStory />
    </StoryScaffold>
  );
}
