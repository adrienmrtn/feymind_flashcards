"use client";

import { useRouter } from "next/navigation";

import { ROW_GHOST, SettingsRow } from "@/components/app/settings/Rows";
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
    <SettingsRow
      label={t("app.settings.replayPaywall.title")}
      hint={t("app.settings.replayPaywall.body")}
      control={
        <button
          type="button"
          onClick={() => {
            clearPaywallDismissal();
            router.push("/app?debug=paywall");
          }}
          className={ROW_GHOST}
        >
          {t("app.settings.replay.go")}
        </button>
      }
    />
  );
}
