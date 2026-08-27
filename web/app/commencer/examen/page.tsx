"use client";

import { useCallback, useState } from "react";

import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";
import { ExamStory } from "@/components/onboarding/ExamStory";

/**
 * Ce que Micabo change, **montré plutôt que demandé.**
 *
 * L'écran demandait une date. Ceux qui n'en avaient pas encore une en inventaient une, et
 * ceux qui en avaient une n'avaient encore rien vu du produit. L'exemple animé dit la chaîne
 * entière — examen, cours, révision, note — avant qu'on pose quoi que ce soit.
 */
export default function ExamStep() {
  const [ready, setReady] = useState(false);
  const onReady = useCallback(() => setReady(true), []);

  return (
    <Scaffold
      eyebrow="Ton examen"
      title="Un examen. Des cours. Une note."
      footer={
        <ContinueButton
          label="Voir comment ça marche"
          enabled={ready}
          shiny
          href="/commencer/comment"
        />
      }
    >
      <ExamStory onReady={onReady} />
    </Scaffold>
  );
}
