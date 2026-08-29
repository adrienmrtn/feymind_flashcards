"use client";

import { ImportStory } from "@/components/onboarding/ImportStory";
import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";

/**
 * Comment un document devient une fiche, montré plutôt que raconté.
 */
export default function ImportStep() {
  return (
    <Scaffold
      title="Importe tes cours."
      footer={<ContinueButton enabled href="/commencer/cartes" />}
    >
      <div className="flex h-full items-center justify-center">
        <ImportStory />
      </div>
    </Scaffold>
  );
}
