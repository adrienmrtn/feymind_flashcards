"use client";

import { useEffect, useState } from "react";
import { ThinkingOrb } from "thinking-orbs";

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
 * Le premier temps **se fait** au lieu de se regarder : on glisse la vignette du PDF, et le bouton
 * ne s'allume qu'après.
 *
 * **Entre deux temps, Micabo travaille sous les yeux.** Ce n'est pas un faux chargement décoratif :
 * c'est le temps du produit, montré ici. Un écran qui remplacerait instantanément le document par
 * sa fiche laisserait croire que la fiche était déjà là.
 *
 * Le troisième temps porte le seul enchantement du parcours : **les cartes se retournent**. Cet
 * écran se voit une fois dans une vie ; c'est exactement là que ce budget se dépense, et c'est pour
 * ça que la vraie session, elle, ne s'animera pas.
 */

const STAGES = [
  { eyebrow: "1 sur 3", title: "Dépose ton cours.", next: "Et ensuite ?" },
  { eyebrow: "2 sur 3", title: "Micabo en écrit la fiche.", next: "Et pour retenir ?" },
  { eyebrow: "3 sur 3", title: "Puis les cartes qui te la font retenir.", next: "J'ai compris" },
] as const;

/** Ce que la transition annonce, et dans l'ordre où elle le fait. */
const WORK = [
  { state: "searching" as const, label: "Micabo lit ton document…" },
  { state: "composing" as const, label: "Micabo écrit la fiche…" },
  { state: "composing" as const, label: "Micabo taille les cartes…" },
];

export default function DemoStep() {
  const [stage, setStage] = useState(0);
  const [dropped, setDropped] = useState(false);
  const [working, setWorking] = useState<number | null>(null);

  const current = STAGES[stage]!;
  const isLast = stage === STAGES.length - 1;

  // La transition se termine d'elle-même. Le compte à rebours vit ici et non dans le gestionnaire
  // de clic, sinon un départ de page laisserait un minuteur derrière lui.
  useEffect(() => {
    if (working === null) return;
    const timer = window.setTimeout(() => {
      setStage(working);
      setWorking(null);
    }, 2_400);
    return () => window.clearTimeout(timer);
  }, [working]);

  if (working !== null) {
    return <Working step={working} />;
  }

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
            if (!isLast) setWorking(stage + 1);
          }}
        />
      }
    >
      {/* La clé change avec l'écran : sans elle, React réutilise le nœud et l'entrée ne rejoue
          pas. C'est ce qui donnait trois écrans qui se remplaçaient sans transition. */}
      <div key={stage} className="rise">
        {stage === 0 ? <DropDemo onDropped={() => setDropped(true)} /> : null}

        {stage === 1 ? (
          <div className="mx-auto w-full max-w-[560px]">
            <div className="paper rounded-group bg-surface p-5">
              <SheetBlocks blocks={TRANSFORMATION_SHEET} tint={DEMO_COURSE.accent} />
              <div className="mt-4">
                <WaterCycleFigure />
              </div>
            </div>
          </div>
        ) : null}

        {/* Deux colonnes ici, pas quatre : la colonne du parcours fait 640 points de large, et
            quatre cartes côte à côte s'y écrasent jusqu'à tronquer leurs propositions. */}
        {stage === 2 ? <DemoCards layout="compact" /> : null}
      </div>
    </Scaffold>
  );
}

/**
 * L'entre-deux : l'orbe, et ce qu'elle attend, écrit.
 *
 * On ne dit pas « chargement » : on dit ce qui se passe. Et le retour n'est jamais porté par la
 * seule animation — le texte est là, et il est annoncé aux lecteurs d'écran.
 */
function Working({ step }: { step: number }) {
  const work = WORK[step] ?? WORK[WORK.length - 1]!;

  return (
    <div className="center-safe flex min-h-[calc(100svh-var(--onboarding-chrome))] flex-col items-center justify-center px-screen">
      <div className="rise flex flex-col items-center">
        <ThinkingOrb state={work.state} size={64} />
        <p className="mt-6 text-[17px] font-semibold text-ink" role="status">
          {work.label}
        </p>
      </div>
    </div>
  );
}
