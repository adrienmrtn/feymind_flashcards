"use client";

import { AiStory } from "@/components/onboarding/stories/AiStory";
import { ExamDateStory } from "@/components/onboarding/stories/ExamDateStory";
import { FeynmanStory } from "@/components/onboarding/stories/FeynmanStory";
import { FormatsStory } from "@/components/onboarding/stories/FormatsStory";
import { PlanStory } from "@/components/onboarding/stories/PlanStory";
import { useI18n } from "@/lib/i18n/client";

import { Reveal } from "./Reveal";
import { SheetStory } from "./SheetStory";

/**
 * **Les six étapes, dans l'ordre où elles se vivent.**
 *
 * Une liste de fonctionnalités dit ce que le produit a ; un récit dit ce qu'on va faire avec.
 * La vitrine suit donc l'ordre de l'app : la date, les documents, la fiche et les cartes, le
 * plan, les questions, l'oral. C'est aussi l'ordre du parcours d'inscription, et ce sont
 * **les mêmes vignettes** : ce que la vitrine promet est ce que le parcours montre ensuite, au
 * pixel près.
 *
 * Une forme unique : la vignette dans un cadre gris d'un côté, la phrase de l'autre, et les
 * côtés alternent. Six mises en page pour un seul propos obligeraient à réapprendre où
 * regarder six fois de suite.
 */
export function Steps() {
  const { t } = useI18n();
  const steps = [
    { key: "date", title: t("landing.step1Title"), body: t("landing.step1Body"), figure: <ExamDateStory /> },
    { key: "documents", title: t("landing.step2Title"), body: t("landing.step2Body"), figure: <FormatsStory /> },
    { key: "sheet", title: t("landing.step3Title"), body: t("landing.step3Body"), figure: <SheetStory /> },
    { key: "plan", title: t("landing.step4Title"), body: t("landing.step4Body"), figure: <PlanStory /> },
    { key: "questions", title: t("landing.step5Title"), body: t("landing.step5Body"), figure: <AiStory /> },
    { key: "feynman", title: t("landing.step6Title"), body: t("landing.step6Body"), figure: <FeynmanStory /> },
  ];

  return (
    <ol className="mt-12 space-y-6 sm:mt-16 sm:space-y-8">
      {steps.map((step, index) => (
        <Reveal key={step.key} as="li" className="paper overflow-hidden rounded-sheet bg-surface">
          <div
            className={`grid items-center gap-8 p-6 sm:p-10 lg:grid-cols-2 lg:gap-14 ${
              index % 2 === 1 ? "lg:[&>*:first-child]:order-2" : ""
            }`}
          >
            <div className="flex min-h-[300px] items-center justify-center rounded-[22px] bg-surface-muted p-6 sm:min-h-[340px] sm:p-8">
              {step.figure}
            </div>
            <div className="max-w-[40ch]">
              <p className="numeral text-[13px] font-semibold text-accent">
                {t("landing.stepEyebrow", { n: index + 1 })}
              </p>
              <h3 className="mt-2 text-[24px] font-bold leading-[1.12] tracking-tight-title text-ink sm:text-[30px]">
                {step.title}
              </h3>
              <p className="mt-4 text-[16px] leading-relaxed text-ink-secondary">{step.body}</p>
            </div>
          </div>
        </Reveal>
      ))}
    </ol>
  );
}
