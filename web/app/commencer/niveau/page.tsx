"use client";

import { resolveStage, stagesFor, type CountryCode } from "@micabo/core";

import { ChoiceRow, ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";
import { useOnboarding } from "@/lib/onboarding/store";

/**
 * Le palier d'études, dans les mots du pays choisi.
 *
 * C'est cet écran qui justifie que le pays passe devant : ses réponses sont celles du système
 * scolaire retenu. Un Américain à qui on proposerait « Licence » ne se reconnaîtrait dans aucune.
 *
 * Et si l'étudiant revient en arrière pour changer de pays, **la réponse est retrouvée plutôt que
 * redemandée** : un lycéen français devient high schooler américain. Quand aucun équivalent
 * n'existe - la santé, les concours - la question se repose, parce qu'inventer une réponse à sa
 * place serait pire.
 */
export default function LevelStep() {
  const { answers, set, ready } = useOnboarding();
  const country: CountryCode = answers.country ?? "fr";
  const stages = stagesFor(country);

  // La réponse déjà donnée, ramenée dans ce pays-ci.
  const resolved = resolveStage(country, {
    id: answers.stageId ?? null,
    tier: answers.tier ?? null,
    level: answers.studyLevel ?? null,
  });

  const selectedId = resolved?.id ?? null;

  return (
    <Scaffold
      eyebrow="Ton parcours"
      title="Qu'est-ce qui te décrit le mieux ?"
      footer={<ContinueButton enabled={Boolean(selectedId) && ready} href="/commencer/matieres" />}
    >
      <div className="max-h-[46svh] space-y-2 overflow-y-auto pr-1 sm:max-h-[52svh]">
        {stages.map((stage) => (
          <ChoiceRow
            key={stage.id}
            emoji={stage.emoji}
            title={stage.title}
            selected={selectedId === stage.id}
            onSelect={() =>
              set({ stageId: stage.id, studyLevel: stage.level, tier: stage.tier })
            }
          />
        ))}
      </div>
    </Scaffold>
  );
}
