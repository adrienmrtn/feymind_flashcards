"use client";

import { StoryScaffold } from "@/components/onboarding/Scaffold";
import { ExamDateStory } from "@/components/onboarding/stories/ExamDateStory";
import { useI18n } from "@/lib/i18n/client";

/**
 * Le premier écran de démonstration : **d'où part un plan.**
 *
 * Il arrive avant l'import, et l'ordre n'est pas indifférent. Montrer les formats d'abord
 * ferait de Micabo un convertisseur de PDF ; montrer la date d'abord dit ce que le produit
 * fait des documents une fois qu'il les a.
 */
export default function ExamDateStep() {
  const { t } = useI18n();
  return (
    <StoryScaffold
      title={
        <>
          {t("onboarding.examenTitleLead")}{" "}
          <span className="text-accent">{t("onboarding.examenTitleDate")}</span>{" "}
          {t("onboarding.examenTitleJoin")}{" "}
          <span className="text-accent">{t("onboarding.examenTitleGrade")}</span>
        </>
      }
      lead={t("onboarding.examenLead")}
    >
      <ExamDateStory />
    </StoryScaffold>
  );
}
