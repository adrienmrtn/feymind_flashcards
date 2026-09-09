"use client";

import { useMemo } from "react";

import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";
import { GradeSlider } from "@/components/onboarding/GradeSlider";
import { useI18n } from "@/lib/i18n/client";
import { BELOW_SCORE, gradeChoices } from "@/lib/onboarding/grades";
import { useOnboarding } from "@/lib/onboarding/store";

/**
 * **La moyenne d'aujourd'hui.**
 *
 * C'est le point de départ, et il n'est pas décoratif : il décide de l'écart avec la moyenne
 * visée, donc de l'intensité du plan. Le demander ici plutôt que de le deviner évite de
 * proposer quatre passages par carte à quelqu'un qui a déjà 17, et deux à quelqu'un qui rame.
 *
 * Deux précautions dans la formulation. La question ne juge pas - « personne ne te juge », dit
 * la phrase, parce qu'on demande à quelqu'un d'écrire son plus mauvais chiffre à un inconnu.
 * Et le premier cran est **en dessous** du barème : une échelle qui commence à la moyenne
 * annonce à celui qui ne l'a pas qu'il n'était pas prévu.
 */
export default function CurrentAverageStep() {
  const { answers, set, ready } = useOnboarding();
  const { t } = useI18n();

  const choices = useMemo(() => {
    const scale = gradeChoices(answers.country);
    return [
      { score: BELOW_SCORE, label: t("onboarding.averageBelow", { grade: scale[0]?.label ?? "" }) },
      ...scale,
    ];
  }, [answers.country, t]);

  function choose(score: number) {
    // La moyenne visée doit rester au-dessus. Remonter son point de départ au-delà de son
    // objectif laisserait l'écran suivant avec une réponse qu'il ne propose plus.
    const target = answers.targetScore;
    set({ currentScore: score, targetScore: target && target > score ? target : undefined });
  }

  return (
    <Scaffold
      title={t("onboarding.averageTitle")}
      footer={<ContinueButton enabled={answers.currentScore !== undefined && ready} />}
      center
    >
      <p className="text-center text-[15px] leading-relaxed text-ink-secondary">
        {t("onboarding.averageLead")}
      </p>

      <div className="mt-7">
        <GradeSlider
          choices={choices}
          selected={answers.currentScore}
          onSelect={choose}
          label={t("onboarding.averageAria")}
        />
      </div>
    </Scaffold>
  );
}
