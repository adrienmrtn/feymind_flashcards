"use client";

import { MikaWritesStory } from "@/components/onboarding/stories/MikaWritesStory";
import { MockExamStory } from "@/components/onboarding/stories/MockExamStory";
import { PathStory } from "@/components/onboarding/stories/PathStory";
import { SupportsStory } from "@/components/onboarding/stories/SupportsStory";
import { useI18n } from "@/lib/i18n/client";

import { Reveal } from "./Reveal";

/**
 * **Les quatre étapes, dans l'ordre où elles se vivent** : tu tapes ou tu déposes, Mika
 * écrit, tu suis le chemin, tu passes l'examen blanc. Ce sont **les mêmes vignettes** que le
 * parcours d'inscription : ce que la vitrine promet est ce que le parcours montre ensuite.
 */
export function Steps() {
  const { t } = useI18n();
  const steps = [
    { key: "supports", title: t("landing.step1Title"), body: t("landing.step1Body"), figure: <SupportsStory /> },
    { key: "mika", title: t("landing.step2Title"), body: t("landing.step2Body"), figure: <MikaWritesStory /> },
    { key: "path", title: t("landing.step3Title"), body: t("landing.step3Body"), figure: <PathStory /> },
    { key: "exam", title: t("landing.step4Title"), body: t("landing.step4Body"), figure: <MockExamStory /> },
  ];

  return (
    <ol className="mt-12 space-y-6 sm:mt-16 sm:space-y-8">
      {steps.map((step, index) => (
        <Reveal key={step.key} as="li" soft className="paper overflow-hidden rounded-sheet bg-surface">
          <div className={`grid items-center gap-8 p-6 sm:p-10 lg:grid-cols-2 lg:gap-14 ${index % 2 === 1 ? "lg:[&>*:first-child]:order-2" : ""}`}>
            <div className="story-part flex min-h-[300px] items-center justify-center rounded-[22px] bg-surface-muted p-6 sm:min-h-[340px] sm:p-8">{step.figure}</div>
            <div className="story-part max-w-[40ch]">
              <p className="numeral text-[13px] font-extrabold text-accent">{t("landing.stepEyebrow", { n: index + 1 })}</p>
              <h3 className="mt-2 text-[24px] font-extrabold leading-[1.12] tracking-tight-title text-ink sm:text-[30px]">{step.title}</h3>
              <p className="mt-4 text-[16px] leading-relaxed text-ink-secondary">{step.body}</p>
            </div>
          </div>
        </Reveal>
      ))}
    </ol>
  );
}
