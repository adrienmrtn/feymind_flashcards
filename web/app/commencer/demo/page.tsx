"use client";

import { useState } from "react";

import { SheetBlocks } from "@/components/sheet/SheetBlocks";
import { DEMO_COURSE, TRANSFORMATION_SHEET } from "@/components/demo/demo-course";
import { DemoCards } from "@/components/landing/DemoCards";
import { RawPage } from "@/components/demo/RawPage";
import { WaterCycleFigure } from "@/components/demo/WaterCycleFigure";
import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";

/**
 * La démonstration, en trois temps.
 *
 * **Le même document à trois états** : brut quand on le dépose, fiché après lecture, découpé en
 * cartes ensuite. C'est ce fil qui fait comprendre le produit, là où trois illustrations sans
 * rapport ne montreraient que trois animations.
 *
 * Les trois temps se traversent à la main plutôt que sur un minuteur, et c'est un choix : un écran
 * qui enchaîne tout seul est un écran arraché sous les yeux. L'étudiant appuie.
 *
 * Le troisième temps porte le seul enchantement du parcours — **les cartes se retournent au
 * survol**. Cet écran se voit une fois dans une vie ; c'est exactement là que ce budget se dépense,
 * et c'est pour ça que la vraie session, elle, ne s'animera pas.
 */

const STAGES = [
  {
    eyebrow: "1 sur 3",
    title: "Tu déposes ton cours.",
    subtitle: "Un polycopié, une photo de tes notes, un PDF, une vidéo de cours.",
    next: "Et ensuite ?",
  },
  {
    eyebrow: "2 sur 3",
    title: "Micabo en écrit la fiche.",
    subtitle: "Un plan, des définitions, ce qui compte en couleur, un schéma quand le cours s'y prête.",
    next: "Et pour retenir ?",
  },
  {
    eyebrow: "3 sur 3",
    title: "Puis les cartes qui te la font retenir.",
    subtitle: "Elles reviennent juste avant que tu oublies. Passe la souris pour voir la réponse.",
    next: "J'ai compris",
  },
] as const;

export default function DemoStep() {
  const [stage, setStage] = useState(0);
  const current = STAGES[stage]!;
  const isLast = stage === STAGES.length - 1;

  return (
    <Scaffold
      eyebrow={current.eyebrow}
      title={current.title}
      subtitle={current.subtitle}
      footer={
        <ContinueButton
          label={current.next}
          enabled
          shiny={stage === 1}
          href={isLast ? "/commencer/ecole" : undefined}
          onPress={() => {
            if (!isLast) setStage(stage + 1);
          }}
        />
      }
    >
      {stage === 0 ? (
        <div className="mx-auto w-full max-w-[300px]">
          <RawPage />
          <p className="mt-4 text-center text-[13px] text-ink-tertiary">
            {DEMO_COURSE.chapter}
          </p>
        </div>
      ) : null}

      {stage === 1 ? (
        <div className="mx-auto w-full max-w-[340px]">
          <div className="paper rounded-button bg-surface p-4">
            <SheetBlocks blocks={TRANSFORMATION_SHEET} tint={DEMO_COURSE.accent} />
            <div className="mt-3.5">
              <WaterCycleFigure />
            </div>
          </div>
        </div>
      ) : null}

      {stage === 2 ? <DemoCards /> : null}
    </Scaffold>
  );
}
