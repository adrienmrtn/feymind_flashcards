"use client";

import { useRouter } from "next/navigation";

import { clearPaywallDismissal } from "@/lib/onboarding/persist";

/**
 * Rejoue le court accueil — preuve sociale, essai, rappel, puis le paywall.
 *
 * Ce n'est pas le parcours `/commencer`. Celui-là pose le pays et les matières.
 * Ici on rouvre seulement l'offre à quatre étapes, posée sur le tableau de bord.
 * Le bouton n'existe qu'en local et sur une preview.
 */
export function ReplayPaywallOnboarding() {
  const router = useRouter();

  return (
    <button
      type="button"
      onClick={() => {
        clearPaywallDismissal();
        router.push("/app?debug=paywall");
      }}
      className="pressable hover-row w-full px-7 py-5 text-left"
    >
      <p className="text-[15px] font-semibold text-ink">Refaire le court accueil</p>
      <p className="mt-1 text-[13px] leading-relaxed text-ink-tertiary">
        Pour déboguer. Preuve sociale, puis le paywall. Tes cours restent.
      </p>
    </button>
  );
}
