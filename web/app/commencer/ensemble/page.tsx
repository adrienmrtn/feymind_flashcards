"use client";

import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";
import { ReviewCarousel } from "@/components/onboarding/ReviewCarousel";
import { useI18n } from "@/lib/i18n/client";
import { gradeLabel } from "@/lib/onboarding/grades";
import { useOnboarding } from "@/lib/onboarding/store";

/**
 * **« On va y arriver ensemble. »**
 *
 * L'écran qui suit les deux moyennes ne demande rien. Il vient de faire écrire un chiffre bas
 * et un chiffre haut ; entre les deux, il y a un écart, et l'écart tout seul décourage. Ce que
 * cet écran ajoute, c'est que d'autres l'ont franchi.
 *
 * L'objectif est répété en toutes lettres, dans le barème du pays, parce qu'un but qu'on
 * relit est un but qu'on garde. Puis les avis, et le bouton.
 */
export default function TogetherStep() {
  const { answers, ready } = useOnboarding();
  const { t } = useI18n();
  const target =
    answers.targetScore !== undefined ? gradeLabel(answers.targetScore, answers.country) : null;

  return (
    <Scaffold
      title={t("onboarding.togetherTitle")}
      footer={<ContinueButton enabled={ready} href="/commencer/parcours" />}
      width="wide"
      center
    >
      <p className="text-center text-[15px] leading-relaxed text-ink-secondary">
        {target ? t("onboarding.togetherGoal", { grade: target }) : t("onboarding.togetherLead")}
      </p>

      <div className="mt-7">
        <ReviewCarousel />
      </div>
    </Scaffold>
  );
}
