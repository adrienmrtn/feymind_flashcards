"use client";

import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";
import { ReviewCarousel } from "@/components/onboarding/ReviewCarousel";
import { useI18n } from "@/lib/i18n/client";
import { useOnboarding } from "@/lib/onboarding/store";

/**
 * **« On va y arriver ensemble. »**
 *
 * L'écran qui suit les deux moyennes ne demande rien. Il vient de faire écrire un chiffre bas
 * et un chiffre haut ; entre les deux, il y a un écart, et l'écart tout seul décourage. Ce que
 * cet écran ajoute, c'est que d'autres l'ont franchi.
 *
 * Il ne répète pas l'objectif : le chiffre vient d'être posé deux écrans plus tôt, et le
 * relire une troisième fois sonne comme une leçon. Une phrase, les avis, le bouton.
 */
export default function TogetherStep() {
  const { ready } = useOnboarding();
  const { t } = useI18n();

  return (
    <Scaffold
      title={t("onboarding.togetherTitle")}
      footer={<ContinueButton enabled={ready} />}
      width="wide"
      center
    >
      <p className="text-center text-[15px] leading-relaxed text-ink-secondary">
        {t("onboarding.togetherLead")}
      </p>

      <div className="mt-7">
        <ReviewCarousel />
      </div>
    </Scaffold>
  );
}
