"use client";

import { StoryScaffold } from "@/components/onboarding/Scaffold";
import { PlanStory } from "@/components/onboarding/stories/PlanStory";
import { useI18n } from "@/lib/i18n/client";

/** Ce que les documents deviennent : une suite de journées, chacune avec son travail nommé. */
export default function PlanStep() {
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
      next="/commencer/ia"
    >
      <PlanStory />
    </StoryScaffold>
  );
}
