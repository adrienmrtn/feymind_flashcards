"use client";

import { BrandMark } from "@/components/BrandMark";
import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";

/**
 * La porte. Un mot, un bouton, rien à apprendre encore.
 */
export default function WelcomeStep() {
  return (
    <Scaffold
      title="Bienvenue sur Micabo."
      footer={<ContinueButton enabled href="/commencer/importer" />}
    >
      <div className="flex h-full flex-col items-center justify-center">
        <BrandMark size={72} />
      </div>
    </Scaffold>
  );
}
