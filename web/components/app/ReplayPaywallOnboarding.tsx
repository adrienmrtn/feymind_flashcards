"use client";

import { useRouter } from "next/navigation";

import { clearPaywallDismissal } from "@/lib/onboarding/persist";

/**
 * Rejoue l'offre, posée sur le tableau de bord.
 *
 * Ce n'est pas le parcours `/commencer`. Celui-là pose le pays et les matières.
 * Ici on rouvre seulement le paywall. Temporaire — à retirer une fois validé.
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
      <p className="text-[15px] font-semibold text-ink">Revoir l&apos;offre</p>
      <p className="mt-1 text-[13px] leading-relaxed text-ink-tertiary">
        Pour déboguer. Tes cours restent.
      </p>
    </button>
  );
}
