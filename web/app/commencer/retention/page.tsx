"use client";

import { RetentionStory } from "@/components/onboarding/RetentionStory";
import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";

/**
 * Pourquoi la répétition espacée gagne — montré, pas affirmé.
 */
export default function RetentionStep() {
  return (
    <Scaffold
      title="Avec une méthode, tu oublies moins."
      footer={<ContinueButton enabled href="/commencer/personnaliser" />}
    >
      <RetentionStory />
    </Scaffold>
  );
}
