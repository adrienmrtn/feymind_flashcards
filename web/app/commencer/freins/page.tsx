"use client";

import { useEffect, useRef } from "react";

import { ChoiceGroup, ChoiceRow, ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";
import { trackOnboardingAnswer } from "@/lib/analytics/funnel";
import { useI18n } from "@/lib/i18n/client";
import { cleanWorries, WORRIES, type Worry } from "@/lib/onboarding/questions";
import { useOnboarding } from "@/lib/onboarding/store";

/**
 * **« Qu'est-ce qui t'inquiète le plus dans tes études ? »** - l'écran `worries` de l'iPhone.
 *
 * Ce n'est pas une question de sondage : chaque réponse change la façon dont Mika écrit.
 * `generate-lesson` en tire une consigne par frein (`difficultyBrief`) - des questions au
 * format exact de l'examen pour le stress, des exemples résolus pas à pas pour les cours durs,
 * plus de repères mnémotechniques pour l'oubli, des blocs courts pour qui ne sait pas par où
 * commencer. Plusieurs réponses, et au moins une.
 */
export default function WorriesStep() {
  const { answers, set, ready } = useOnboarding();
  const { t } = useI18n();
  const chosen = cleanWorries(answers.worries);

  // L'entonnoir reçoit les freins une fois, en quittant l'écran : pas à chaque coche.
  const latest = useRef(chosen);
  latest.current = chosen;
  useEffect(
    () => () => {
      if (latest.current.length > 0) trackOnboardingAnswer("worries", latest.current.join(","));
    },
    [],
  );

  function toggle(worry: Worry) {
    const next = chosen.includes(worry) ? chosen.filter((item) => item !== worry) : [...chosen, worry];
    set({ worries: cleanWorries(next) });
  }

  return (
    <Scaffold
      title={t("onboarding.worriesTitle")}
      lead={t("onboarding.worriesLead")}
      footer={<ContinueButton enabled={chosen.length > 0 && ready} />}
      center
    >
      <ChoiceGroup label={t("onboarding.worriesTitle")} multi className="space-y-2">
        {WORRIES.map((worry) => (
          <ChoiceRow
            key={worry.id}
            emoji={worry.emoji}
            title={t(`onboarding.worry.${worry.id}`)}
            selected={chosen.includes(worry.id)}
            onSelect={() => toggle(worry.id)}
            multi
          />
        ))}
      </ChoiceGroup>
    </Scaffold>
  );
}
