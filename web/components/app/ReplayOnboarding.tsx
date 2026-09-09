"use client";

import { useTransition } from "react";

import { replayOnboarding } from "@/lib/actions/onboarding";
import { ONBOARDING_REPLAY_STORAGE } from "@/lib/auth/onboarding-replay";
import { ROW_GHOST, SettingsRow } from "@/components/app/settings/Rows";
import { useI18n } from "@/lib/i18n/client";
import { clearStoredAnswers } from "@/lib/onboarding/persist";

/**
 * Rejoue le parcours d'accueil, pour déboguer.
 *
 * Une session ouverte renvoyait toujours à l'app. Ici on pose un marqueur,
 * on oublie les réponses locales, et on rouvre le tunnel.
 */
export function ReplayOnboarding() {
  const { t } = useI18n();
  const [pending, startTransition] = useTransition();

  return (
    <SettingsRow
      label={t("app.settings.replayOnboarding.title")}
      hint={t("app.settings.replayOnboarding.body")}
      control={
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
          className={ROW_GHOST}
        >
          {pending
            ? t("app.settings.replayOnboarding.opening")
            : t("app.settings.replay.go")}
        </button>
      }
    />
  );
}
