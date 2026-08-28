"use client";

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
        <div className="flex h-12 items-center justify-center rounded-pill bg-ink px-5 text-[16px] font-bold tracking-tight text-on-ink">
          Micabo
        </div>
      </div>
    </Scaffold>
  );
}
