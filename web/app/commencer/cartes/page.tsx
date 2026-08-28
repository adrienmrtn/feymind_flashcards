"use client";

import { FlashcardStory } from "@/components/onboarding/FlashcardStory";
import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";

/**
 * La fiche se découpe. Les cartes se retournent.
 */
export default function CardsIntroStep() {
  return (
    <Scaffold
      title="On transforme tes fiches en flashcards."
      footer={<ContinueButton enabled href="/commencer/reussir" />}
    >
      <FlashcardStory />
    </Scaffold>
  );
}
