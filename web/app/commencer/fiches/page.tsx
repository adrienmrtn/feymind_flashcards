"use client";

import { SheetStory } from "@/components/onboarding/SheetStory";
import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";

/**
 * Ce qui sort de l'import : des fiches, montrées telles qu'elles sont écrites.
 */
export default function SheetsStep() {
  return (
    <Scaffold
      title="Micabo transforme tes cours en fiches."
      footer={<ContinueButton enabled href="/commencer/cartes" />}
    >
      <SheetStory />
    </Scaffold>
  );
}
