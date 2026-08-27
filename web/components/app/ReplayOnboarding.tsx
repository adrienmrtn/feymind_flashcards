"use client";

import { useTransition } from "react";

import { replayOnboarding } from "@/lib/actions/onboarding";
import { ONBOARDING_REPLAY_STORAGE } from "@/lib/auth/onboarding-replay";
import { clearStoredAnswers } from "@/lib/onboarding/persist";

/**
 * Rejoue le parcours d'accueil, pour déboguer.
 *
 * Une session ouverte renvoyait toujours à l'app. Ici on pose un marqueur,
 * on oublie les réponses locales, et on rouvre le tunnel.
 */
export function ReplayOnboarding() {
  const [pending, startTransition] = useTransition();

  return (
    <button
      type="button"
      disabled={pending}
      onClick={() => {
        try {
          sessionStorage.setItem(ONBOARDING_REPLAY_STORAGE, "1");
        } catch {
          // Sans stockage, le cookie du serveur suffit encore au middleware.
        }
        clearStoredAnswers();
        startTransition(() => {
          void replayOnboarding();
        });
      }}
      className="pressable hover-tile mt-3 w-full rounded-group bg-surface px-5 py-4 text-left paper"
    >
      <p className="text-[15px] font-semibold text-ink">🔁 Refaire l&apos;accueil</p>
      <p className="mt-1 text-[13px] leading-relaxed text-ink-tertiary">
        {pending ? "Ouverture du parcours…" : "Pour déboguer. Tes cours restent."}
      </p>
    </button>
  );
}
