"use client";

import { FlashcardStory } from "@/components/onboarding/FlashcardStory";
import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";

/**
 * Une session, en petit : on répond, on se note, la carte revient.
 */
export default function CardsIntroStep() {
  return (
    <Scaffold
      title="On t'aide à comprendre ton cours."
      footer={<ContinueButton enabled href="/commencer/reussir" />}
    >
      <FlashcardStory />
    </Scaffold>
  );
}
