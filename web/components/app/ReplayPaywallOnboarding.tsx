"use client";

import { useRouter } from "next/navigation";

import { useI18n } from "@/lib/i18n/client";
import { clearPaywallDismissal } from "@/lib/onboarding/persist";

/**
 * Rejoue le court accueil — preuve sociale, essai, rappel, puis le paywall.
 *
 * Ce n'est pas le parcours `/commencer`. Celui-là pose le pays et les matières.
 * Ici on rouvre seulement l'offre à quatre étapes, posée sur le tableau de bord.
 * Temporaire — à retirer une fois le parcours validé.
 */
export function ReplayPaywallOnboarding() {
  const { t } = useI18n();
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
      <p className="text-[15px] font-semibold text-ink">{t("app.settings.replayPaywall.title")}</p>
      <p className="mt-1 text-[13px] leading-relaxed text-ink-tertiary">
        {t("app.settings.replayPaywall.body")}
      </p>
    </button>
  );
}
