"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

import { ChoiceGroup, ChoiceRow, ContinueButton, Scaffold, useAdvance } from "@/components/onboarding/Scaffold";
import { trackOnboardingAnswer } from "@/lib/analytics/funnel";
import { useI18n } from "@/lib/i18n/client";
import { trackById, yearById } from "@/lib/onboarding/school-system";
import { useOnboarding } from "@/lib/onboarding/store";

/**
 * **L'année, dans la filière choisie** : « Terminale », « 11. Klasse », « 2º de Bachillerato ».
 *
 * C'est la réponse qui va le plus loin dans la leçon : `generate-lesson` la lit telle quelle
 * (`year`), et c'est elle qui fait la différence entre une leçon de seconde et une leçon de
 * terminale sur le même chapitre. Elle ne se pose qu'aux pays dont on connaît les filières ; un
 * appui avance.
 *
 * Arrivé ici sans filière (un lien direct, un retour après avoir changé de pays), on repart à
 * l'écran du niveau plutôt que de proposer des années qui ne disent rien.
 */
export default function YearStep() {
  const { answers, set, ready } = useOnboarding();
  const { t } = useI18n();
  const router = useRouter();
  const advance = useAdvance();
  const track = trackById(answers.trackId, answers.country);
  const selected = yearById(answers.yearId, track);

  useEffect(() => {
    if (ready && !track) router.replace("/commencer/niveau");
  }, [ready, router, track]);

  return (
    <Scaffold
      title={t("onboarding.yearTitle")}
      lead={track ? `${track.emoji} ${track.title}` : undefined}
      footer={<ContinueButton enabled={Boolean(selected) && ready} />}
      center
    >
      <ChoiceGroup label={t("onboarding.yearTitle")} className="space-y-2">
        {(track?.years ?? []).map((year) => (
          <ChoiceRow
            key={year.id}
            title={year.title}
            selected={selected?.id === year.id}
            onSelect={() => {
              set({ yearId: year.id });
              trackOnboardingAnswer("year", year.id);
              advance({ auto: true });
            }}
          />
        ))}
      </ChoiceGroup>
    </Scaffold>
  );
}
