"use client";

import { WelcomeStory } from "@/components/onboarding/WelcomeStory";
import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";

/**
 * La porte. Un mot, une pile de fiches, rien à apprendre encore.
 */
export default function WelcomeStep() {
  return (
    <Scaffold
      title="Bienvenue sur Micabo."
      footer={<ContinueButton enabled href="/commencer/importer" />}
    >
      <div className="flex h-full items-center justify-center">
        <WelcomeStory />
      </div>
    </Scaffold>
  );
}
