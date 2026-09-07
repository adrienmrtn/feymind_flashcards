"use client";

import { Alert, AlertDescription } from "@/components/ui/alert";
import { useI18n } from "@/lib/i18n/client";

/**
 * « Tu voulais dire … ? », posé sous le champ quand l'adresse ressemble à une autre.
 *
 * C'est une **question**, et les deux réponses partent. `gmial.com` existe, se vend et
 * garde le courrier qu'on lui donne : personne ne peut jurer à la place de l'élève que ce
 * n'est pas sa boîte. Ce qu'on sait, c'est que neuf fois sur dix c'est `gmail.com` et un
 * doigt trop rapide - et qu'un lien parti là-bas revient en rebond, sur un envoyeur qu'on
 * partage avec tout Supabase.
 *
 * La correction est donc l'action principale, et passer outre reste possible d'un clic.
 * L'inverse - bloquer - enfermerait dehors les rares qui ont raison, et ceux-là n'ont
 * aucun autre moyen d'entrer.
 */
export function EmailSuggestion({
  typed,
  corrected,
  onAccept,
  onKeep,
}: {
  typed: string;
  corrected: string;
  onAccept: () => void;
  onKeep: () => void;
}) {
  const { t } = useI18n();

  return (
    <Alert variant="warning" className="rise mt-3" role="status">
      <AlertDescription className="text-[14px] text-ink-secondary">
        <p>
          {t("onboarding.emailSuggestionQuestion")}{" "}
          <button
            type="button"
            onClick={onAccept}
            className="underline-draw font-semibold text-ink"
          >
            {corrected}
          </button>
        </p>
        <button
          type="button"
          onClick={onKeep}
          className="self-start text-[13px] text-ink-tertiary underline-draw"
        >
          {t("onboarding.emailSuggestionKeep", { email: typed })}
        </button>
      </AlertDescription>
    </Alert>
  );
}
