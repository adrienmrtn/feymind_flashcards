"use client";

import { ResultsStory } from "@/components/onboarding/stories/ResultsStory";
import { useI18n } from "@/lib/i18n/client";

import { Reveal } from "./Reveal";

/**
 * Ce que ça donne : **la seule mesure que la vitrine avance.**
 *
 * Deux barres et le chiffre entre les deux, dessinées par la vignette du parcours
 * d'inscription. Un seul nombre, parce qu'une page qui en aligne six ne se fait plus croire
 * sur aucun.
 */
export function Proof() {
  const { t } = useI18n();
  return (
    <Reveal className="paper grid items-center gap-8 overflow-hidden rounded-sheet bg-surface p-6 sm:p-10 lg:grid-cols-[1fr_minmax(0,380px)] lg:gap-14">
      <div className="max-w-[44ch]">
        <p className="eyebrow text-ink-tertiary">{t("landing.resultsEyebrow")}</p>
        <h2 className="mt-2.5 text-[30px] font-bold leading-[1.08] tracking-tight-title text-ink sm:text-[40px]">
          {t("landing.resultsTitle")}
        </h2>
        <p className="mt-4 text-[16px] leading-relaxed text-ink-secondary">{t("landing.resultsNote")}</p>
      </div>
      <div className="flex items-center justify-center rounded-[22px] bg-surface-muted p-6 sm:p-8">
        <ResultsStory />
      </div>
    </Reveal>
  );
}
