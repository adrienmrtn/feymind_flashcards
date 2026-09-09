"use client";

import { useState, useTransition } from "react";

import {
  CONTENT_LANGUAGES,
  LANGUAGE_LABELS,
  type ContentLanguage,
} from "@micabo/core";

import { ROW_FIELD, SettingsRow } from "@/components/app/settings/Rows";
import { updateSettings } from "@/lib/actions/profile";
import { useI18n } from "@/lib/i18n/client";

/**
 * La langue des **prochaines** fiches.
 *
 * Celles déjà écrites restent dans la leur. On ne réécrit pas un cours
 * parce qu'on a changé d'avis sur l'anglais.
 */
export function SheetLanguageCard({ initial }: { initial: ContentLanguage }) {
  const [language, setLanguage] = useState(initial);
  const [pending, startTransition] = useTransition();
  const { t } = useI18n();

  return (
    <SettingsRow
      label={t("settings.sheetLanguage")}
      htmlFor="sheet-language"
      hint={t("settings.sheetLanguageHelp")}
      tour="reglages-langue"
      control={
        <select
          id="sheet-language"
          value={language}
          disabled={pending}
          onChange={(event) => {
            const next = event.target.value as ContentLanguage;
            setLanguage(next);
            startTransition(async () => {
              await updateSettings({ sheetLanguage: next });
            });
          }}
          className={`${ROW_FIELD} w-[15rem] max-w-full font-medium`}
        >
          {CONTENT_LANGUAGES.map((code) => (
            <option key={code} value={code}>
              {LANGUAGE_LABELS[code]}
            </option>
          ))}
        </select>
      }
    />
  );
}
