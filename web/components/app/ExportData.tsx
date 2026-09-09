"use client";

import { useState, useTransition } from "react";

import { ROW_GHOST, SettingsRow } from "@/components/app/settings/Rows";
import { exportAccountData } from "@/lib/actions/profile";
import { useI18n } from "@/lib/i18n/client";

/**
 * Télécharge une copie JSON des données du compte.
 *
 * Le fichier n'est pas stocké : il est assemblé à la demande et part dans le
 * navigateur. C'est le chemin annoncé par la politique de confidentialité.
 */
export function ExportData() {
  const { t } = useI18n();
  const [pending, startTransition] = useTransition();
  const [failure, setFailure] = useState<string | null>(null);

  function download() {
    setFailure(null);
    startTransition(async () => {
      const result = await exportAccountData();
      if (result.status !== "ok" || !result.payload) {
        setFailure(result.message ?? t("app.settings.export.error"));
        return;
      }

      const blob = new Blob([JSON.stringify(result.payload, null, 2)], {
        type: "application/json",
      });
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = `micabo-donnees-${new Date().toISOString().slice(0, 10)}.json`;
      link.click();
      URL.revokeObjectURL(url);
    });
  }

  return (
    <SettingsRow
      label={t("app.settings.export.title")}
      hint={
        <>
          {t("app.settings.export.body")}
          {failure ? (
            <>
              <br />
              <span className="text-negative" role="alert">
                {failure}
              </span>
            </>
          ) : null}
        </>
      }
      control={
        <button type="button" onClick={download} disabled={pending} className={ROW_GHOST}>
          {pending ? t("app.settings.export.pending") : t("app.settings.export.download")}
        </button>
      }
    />
  );
}
