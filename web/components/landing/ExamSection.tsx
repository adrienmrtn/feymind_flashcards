"use client";

import { ExamDateStory } from "@/components/onboarding/stories/ExamDateStory";
import { MockExamStory } from "@/components/onboarding/stories/MockExamStory";
import { useI18n } from "@/lib/i18n/client";

import { Reveal } from "./Reveal";

/**
 * **L'examen, en deux vignettes** : la date qu'on pose et les jours qui restent ; la copie
 * d'un examen blanc, notée dans le barème du pays.
 */
export function ExamSection() {
  const { t } = useI18n();
  return (
    <Reveal className="paper grid gap-6 overflow-hidden rounded-sheet bg-surface p-6 sm:p-10 lg:grid-cols-2 lg:gap-10">
      <figure className="flex flex-col items-center gap-4 rounded-[22px] bg-surface-muted p-6 sm:p-8">
        <ExamDateStory />
        <figcaption className="max-w-[36ch] text-center text-[14px] leading-relaxed text-ink-secondary">{t("landing.examDateCaption")}</figcaption>
      </figure>
      <figure className="flex flex-col items-center gap-4 rounded-[22px] bg-surface-muted p-6 sm:p-8">
        <MockExamStory />
        <figcaption className="max-w-[36ch] text-center text-[14px] leading-relaxed text-ink-secondary">{t("landing.examMockCaption")}</figcaption>
      </figure>
    </Reveal>
  );
}
