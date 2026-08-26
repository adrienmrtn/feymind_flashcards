"use client";

import { Scaffold, ContinueButton } from "@/components/onboarding/Scaffold";
import { WaterCycleFigure } from "@/components/demo/WaterCycleFigure";

/**
 * L'accueil du parcours.
 *
 * Une phrase, et rien à faire. C'est le seul écran qui n'a ni question ni habillage : il pose ce
 * que Micabo prétend être, et laisse la main.
 */
export default function WelcomeStep() {
  return (
    <Scaffold
      eyebrow="Le parcours"
      title={
        <>
          Bienvenue sur la première intelligence artificielle qui aide les élèves à travailler et à
          approcher les examens <span className="text-accent">sans stress</span>.
        </>
      }
      footer={<ContinueButton label="C'est parti" enabled href="/commencer/compte" />}
    >
      <div className="mx-auto w-full max-w-[300px]">
        <WaterCycleFigure />
        <p className="mt-5 text-center text-[13px] text-ink-tertiary">
          Un cours devient une fiche, puis des cartes.
        </p>
      </div>
    </Scaffold>
  );
}
