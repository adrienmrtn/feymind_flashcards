"use client";

import { StoryScaffold } from "@/components/onboarding/Scaffold";
import { FeynmanStory } from "@/components/onboarding/stories/FeynmanStory";
import { useI18n } from "@/lib/i18n/client";

/** La seule mesure honnête de ce qu'on sait : l'expliquer à voix haute, et se faire reprendre. */
export default function FeynmanStep() {
  const { t } = useI18n();
  return (
    <StoryScaffold
      title={
        <>
          {t("onboarding.feynmanTitleLead")}{" "}
          <span className="text-accent">{t("onboarding.feynmanTitleStrong")}</span>
        </>
      }
      lead={t("onboarding.feynmanLead")}
    >
      <FeynmanStory />
    </StoryScaffold>
  );
}
