"use client";

import { useState } from "react";

import { SheetBlocks } from "@/components/sheet/SheetBlocks";
import { DEMO_COURSE, TRANSFORMATION_SHEET } from "@/components/demo/demo-course";
import { DemoCards } from "@/components/landing/DemoCards";
import { WaterCycleFigure } from "@/components/demo/WaterCycleFigure";
import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";
import { DropDemo } from "@/components/onboarding/DropDemo";

/**
 * La démonstration, en trois temps.
 *
 * **Le même document à trois états** : brut quand on le dépose, fiché après lecture, découpé en
 * cartes ensuite. C'est ce fil qui fait comprendre le produit, là où trois illustrations sans
 * rapport ne montreraient que trois animations.
 *
 * Le premier temps **se fait** au lieu de se regarder : on glisse la vignette du PDF dans la zone,
 * et le bouton ne s'allume qu'après. Un écran qui annonce « tu déposes ton cours » en montrant une
 * page immobile demande de croire ; celui-ci le fait faire.
 *
 * Le troisième temps porte le seul enchantement du parcours — **les cartes se retournent au
 * survol**. Cet écran se voit une fois dans une vie ; c'est exactement là que ce budget se dépense,
 * et c'est pour ça que la vraie session, elle, ne s'animera pas.
 */

const STAGES = [
  { eyebrow: "1 sur 3", title: "Dépose ton cours.", next: "Et ensuite ?" },
  { eyebrow: "2 sur 3", title: "Micabo en écrit la fiche.", next: "Et pour retenir ?" },
  { eyebrow: "3 sur 3", title: "Puis les cartes qui te la font retenir.", next: "J'ai compris" },
] as const;

export default function DemoStep() {
  const [stage, setStage] = useState(0);
  const [dropped, setDropped] = useState(false);
  const current = STAGES[stage]!;
  const isLast = stage === STAGES.length - 1;

  return (
    <Scaffold
      eyebrow={current.eyebrow}
      title={current.title}
      footer={
        <ContinueButton
          label={current.next}
          enabled={stage > 0 || dropped}
          shiny={stage === 1}
          href={isLast ? "/commencer/ecole" : undefined}
          onPress={() => {
            if (!isLast) setStage(stage + 1);
          }}
        />
      }
    >
      {stage === 0 ? <DropDemo onDropped={() => setDropped(true)} /> : null}

      {stage === 1 ? (
        <div className="mx-auto w-full max-w-[380px]">
          <div className="paper rise rounded-group bg-surface p-5">
            <SheetBlocks blocks={TRANSFORMATION_SHEET} tint={DEMO_COURSE.accent} />
            <div className="mt-4">
              <WaterCycleFigure />
            </div>
          </div>
        </div>
      ) : null}

      {stage === 2 ? <DemoCards /> : null}
    </Scaffold>
  );
}
