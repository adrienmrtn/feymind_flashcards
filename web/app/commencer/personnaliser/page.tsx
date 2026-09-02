"use client";

import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";
import { useI18n } from "@/lib/i18n/client";

/**
 * La charnière du parcours.
 *
 * Avant : on montrait le produit. Après : on pose quatre questions. Sans cet
 * écran, la première question tombe sans qu'on sache pourquoi on y répond —
 * et une question dont on ignore l'usage se remplit au hasard.
 */
export default function PersonalizeIntroStep() {
  const { t } = useI18n();
  const steps = [
    { emoji: "🌍", title: t("onboarding.previewCountry"), detail: t("onboarding.previewCountryDetail") },
    { emoji: "🎓", title: t("onboarding.previewLevel"), detail: t("onboarding.previewLevelDetail") },
    { emoji: "📚", title: t("onboarding.previewSubjects"), detail: t("onboarding.previewSubjectsDetail") },
    { emoji: "🏫", title: t("onboarding.previewSchool"), detail: t("onboarding.previewSchoolDetail") },
  ];
  return (
    <Scaffold
      title={t("onboarding.personnaliserTitle")}
      footer={<ContinueButton label={t("onboarding.letsGo")} enabled href="/commencer/pays" />}
    >
      <div className="mx-auto w-full max-w-[420px]">
        <p className="text-[14.5px] leading-relaxed text-ink-secondary">
          {t("onboarding.personnaliserIntro")}
        </p>

        <div className="mt-4 space-y-2">
          {steps.map((step, index) => (
            <div
              key={step.title}
              className="flex items-center gap-3.5 rounded-button bg-surface px-4 py-3 paper"
              style={{
                animation: `micabo-rise 380ms var(--ease-out-strong) ${index * 90}ms both`,
              }}
            >
              <span aria-hidden className="emoji text-[22px]">
                {step.emoji}
              </span>
              <span className="min-w-0 flex-1">
                <span className="block text-[15px] font-medium text-ink">{step.title}</span>
                <span className="mt-0.5 block text-[12.5px] text-ink-tertiary">{step.detail}</span>
              </span>
            </div>
          ))}
        </div>
      </div>
    </Scaffold>
  );
}
