"use client";

import { ThinkingOrb } from "thinking-orbs";

import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";
import { useI18n } from "@/lib/i18n/client";

/**
 * La charnière du parcours.
 *
 * Avant : on montrait le produit. Après : on pose des questions. Sans cet écran, la première
 * question tombe sans qu'on sache pourquoi on y répond - et une question dont on ignore
 * l'usage se remplit au hasard.
 *
 * L'écran annonçait ces questions une par une, avec pour chacune son emoji et sa raison
 * d'être. C'était **quatre fois la même promesse**, écrite juste avant qu'on la tienne : la
 * page suivante pose la question, et la réponse elle-même dit à quoi elle sert. Ne restent que
 * le titre, le bouton, et l'orbe qui tourne - la même que celle qui réfléchit partout ailleurs
 * dans Micabo, ce qui donne à cette charnière la seule chose qu'elle doit dire : ça travaille
 * déjà pour toi.
 */
export default function PersonalizeIntroStep() {
  const { t } = useI18n();

  return (
    <Scaffold
      title={t("onboarding.personnaliserTitle")}
      footer={<ContinueButton label={t("onboarding.letsGo")} enabled href="/commencer/pays" />}
      center
    >
      {/* L'orbe ne se dessine qu'en 64 ou en 20 ; ici elle doit tenir l'écran, donc on
          l'agrandit à l'échelle plutôt que de la redessiner - c'est du rendu vectoriel, il ne
          se pixellise pas. */}
      <div className="flex h-[190px] w-full items-center justify-center overflow-hidden">
        <div className="scale-[3]">
          <ThinkingOrb state="composing" size={64} />
        </div>
      </div>
    </Scaffold>
  );
}
