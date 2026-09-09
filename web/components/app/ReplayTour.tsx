"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";

import { ROW_GHOST, SettingsRow } from "@/components/app/settings/Rows";
import { resetTour } from "@/lib/actions/tour";
import { useI18n } from "@/lib/i18n/client";

/**
 * Refaire la visite guidée, depuis les réglages.
 *
 * Posé à côté de « Refaire l'accueil », et pour la même raison : ce qui ne se
 * présente qu'une fois doit pouvoir se redemander. La différence est qu'ici ce
 * n'est pas un outil de mise au point mais une entrée normale du produit, donc
 * elle ne dit pas « pour déboguer ».
 *
 * On repart sur l'accueil : c'est la première page de la visite, et rester sur
 * les réglages ferait commencer la découverte par son écran le plus aride.
 */
export function ReplayTour() {
  const { t } = useI18n();
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  return (
    <SettingsRow
      label={t("app.settings.replayTour.title")}
      hint={t("app.settings.replayTour.body")}
      control={
        <button
          type="button"
          disabled={pending}
          onClick={() => {
            startTransition(async () => {
              await resetTour();
              router.push("/app");
            });
          }}
          className={ROW_GHOST}
        >
          {pending ? t("app.settings.replayTour.pending") : t("app.settings.replay.go")}
        </button>
      }
    />
  );
}
