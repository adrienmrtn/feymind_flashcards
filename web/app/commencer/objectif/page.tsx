"use client";

import { useMemo } from "react";

import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";
import { GradePicker } from "@/components/onboarding/GradePicker";
import { useI18n } from "@/lib/i18n/client";
import { gradeLabel, targetChoices } from "@/lib/onboarding/grades";
import { useOnboarding } from "@/lib/onboarding/store";

/**
 * **La moyenne visée.**
 *
 * Elle ne peut qu'être au-dessus de l'actuelle, et ce n'est pas une politesse : l'écart entre
 * les deux est ce qui règle l'intensité du plan. Un objectif égal ou inférieur à ce qu'on a
 * déjà ne demande aucun travail, et l'écran suivant n'aurait rien à promettre. Les moyennes
 * plus basses ne sont donc pas grisées, elles ne sont pas là - un bouton qui refuse d'être
 * appuyé est une question à laquelle on n'a pas compris la réponse.
 *
 * Celui qui a déjà le haut du barème n'a rien à choisir. Il le lit, et il continue : lui
 * proposer de viser plus haut que le maximum serait se moquer de lui.
 */
export default function TargetAverageStep() {
  const { answers, set, ready } = useOnboarding();
  const { t } = useI18n();
  const choices = useMemo(
    () => targetChoices(answers.currentScore, answers.country),
    [answers.country, answers.currentScore],
  );

  const current = answers.currentScore;
  const currentLabel = current !== undefined ? gradeLabel(current, answers.country) : null;
  // Un objectif hérité d'une moyenne actuelle plus haute n'a plus cours.
  const selected =
    answers.targetScore !== undefined &&
    choices.some((choice) => choice.score === answers.targetScore)
      ? answers.targetScore
      : undefined;

  const atTop = choices.length === 0;

  return (
    <Scaffold
      title={t("onboarding.targetTitle")}
      footer={
        <ContinueButton
          enabled={(atTop || selected !== undefined) && ready}
          href="/commencer/ensemble"
        />
      }
      width="wide"
      center
    >
      <p className="text-center text-[15px] leading-relaxed text-ink-secondary">
        {atTop ? t("onboarding.targetAtTop") : t("onboarding.targetLead")}
      </p>

      {atTop ? null : (
        <div className="mt-7">
          <GradePicker
            choices={choices}
            selected={selected}
            onSelect={(score) => set({ targetScore: score })}
            label={t("onboarding.targetAria")}
          />
        </div>
      )}

      <p className="mt-6 h-5 text-center text-[13px] text-ink-tertiary">
        {currentLabel ? t("onboarding.targetFrom", { grade: currentLabel }) : null}
      </p>
    </Scaffold>
  );
}
