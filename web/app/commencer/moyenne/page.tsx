"use client";

import { useMemo } from "react";

import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";
import { GradeSlider } from "@/components/onboarding/GradeSlider";
import { AccentText } from "@/components/onboarding/AccentText";
import { useI18n } from "@/lib/i18n/client";
import { BELOW_SCORE, gradeChoices, targetChoices } from "@/lib/onboarding/grades";
import { useOnboarding } from "@/lib/onboarding/store";

/**
 * **D'où l'on part, et où l'on va** : la moyenne d'aujourd'hui et la moyenne visée, sur un seul
 * écran.
 *
 * C'étaient deux écrans, et ils disaient une seule chose : un écart. Côte à côte, l'écart se
 * voit - on règle le point de départ, l'objectif se décale avec lui, et la distance entre les
 * deux chiffres est la réponse. Les deux partent dans le cookie `micabo.learner`, et
 * `generate-lesson` s'en sert : plus d'exemples résolus pour qui est en difficulté, des
 * questions plus exigeantes pour qui vise haut (`difficultyBrief`).
 *
 * Deux précautions gardées de l'écran d'avant. La question ne juge pas - « personne ne te
 * juge ». Et le premier cran est **en dessous** du barème : une échelle qui commence à la
 * moyenne annonce à celui qui ne l'a pas qu'il n'était pas prévu. L'objectif, lui, est toujours
 * strictement au-dessus : un objectif atteint ne demande aucun travail.
 */
export default function AveragesStep() {
  const { answers, set, ready } = useOnboarding();
  const { t } = useI18n();

  const current = useMemo(() => {
    const scale = gradeChoices(answers.country);
    return [{ score: BELOW_SCORE, label: t("onboarding.averageBelow", { grade: scale[0]?.label ?? "" }) }, ...scale];
  }, [answers.country, t]);
  const targets = useMemo(() => targetChoices(answers.currentScore, answers.country), [answers.country, answers.currentScore]);

  // Un objectif hérité d'une moyenne actuelle plus haute n'a plus cours.
  const target =
    answers.targetScore !== undefined && targets.some((choice) => choice.score === answers.targetScore)
      ? answers.targetScore
      : undefined;
  const atTop = answers.currentScore !== undefined && targets.length === 0;

  function chooseCurrent(score: number) {
    // L'objectif doit rester au-dessus : il remonte avec le point de départ plutôt que de
    // laisser une réponse que le curseur ne propose plus.
    const kept = answers.targetScore;
    set({ currentScore: score, targetScore: kept !== undefined && kept > score ? kept : undefined });
  }

  return (
    <Scaffold
      title={<AccentText text={t("onboarding.averagesTitle")} />}
      lead={t("onboarding.averageLead")}
      footer={<ContinueButton enabled={answers.currentScore !== undefined && (atTop || target !== undefined) && ready} />}
      center
      width="wide"
    >
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <div className="rounded-[20px] border-[1.5px] border-stroke bg-surface px-4 pb-4 pt-4">
          <GradeSlider
            choices={current}
            selected={answers.currentScore}
            onSelect={chooseCurrent}
            label={t("onboarding.averageAria")}
            heading={t("onboarding.goalNow")}
          />
        </div>

        <div className="rounded-[20px] border-[1.5px] border-accent/40 bg-accent-soft/50 px-4 pb-4 pt-4">
          {atTop ? (
            <div className="flex h-full min-h-[118px] flex-col items-center justify-center text-center">
              <p className="text-[13px] font-bold text-accent">{t("onboarding.goalTarget")}</p>
              <p className="mt-2 max-w-[26ch] text-[14.5px] font-semibold leading-snug text-ink">{t("onboarding.targetAtTop")}</p>
            </div>
          ) : answers.currentScore === undefined ? (
            <div className="min-h-[118px]" />
          ) : (
            <GradeSlider
              key={answers.currentScore}
              choices={targets}
              selected={target}
              onSelect={(score) => set({ targetScore: score })}
              label={t("onboarding.targetAria")}
              heading={t("onboarding.goalTarget")}
              tone="accent"
              // Deux crans au-dessus d'où l'on part : un objectif qui s'ouvre sur la valeur juste
              // au-dessus de la sienne ne ressemble pas à un objectif.
              fallbackIndex={1}
            />
          )}
        </div>
      </div>
    </Scaffold>
  );
}
