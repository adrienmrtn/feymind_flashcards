"use client";

import { StoryScaffold } from "@/components/onboarding/Scaffold";
import { PathStory } from "@/components/onboarding/stories/PathStory";
import { useI18n } from "@/lib/i18n/client";

/** Ce que le cours devient : un chemin, étape par étape, jusqu'au quiz final. */
export default function PathStep() {
  const { t } = useI18n();
  return (
    <StoryScaffold
      title={
        <>
          {t("onboarding.planTitleLead")}{" "}
          <span className="text-accent">{t("onboarding.planTitleStrong")}</span>
        </>
      }
      lead={t("onboarding.planLead")}
    >
      <PathStory />
    </StoryScaffold>
  );
}
