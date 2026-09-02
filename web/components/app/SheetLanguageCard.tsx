"use client";

import { useState, useTransition } from "react";

import {
  CONTENT_LANGUAGES,
  LANGUAGE_LABELS,
  type ContentLanguage,
} from "@micabo/core";

import { updateSettings } from "@/lib/actions/profile";
import { useI18n } from "@/lib/i18n/client";

/**
 * La langue des **prochaines** fiches.
 *
 * Celles déjà écrites restent dans la leur. On ne réécrit pas un cours
 * parce qu'on a changé d'avis sur l'anglais.
 */
export function SheetLanguageCard({
  initial,
  embedded = false,
}: {
  initial: ContentLanguage;
  /** Sans carte autour : la page réglages l'embarque déjà. */
  embedded?: boolean;
}) {
  const [language, setLanguage] = useState(initial);
  const [pending, startTransition] = useTransition();
  const { t } = useI18n();

  return (
    <section className={embedded ? "" : "paper hover-tile rounded-group bg-surface p-6"}>
      <p className="text-[13px] text-ink-tertiary">{t("settings.sheetLanguage")}</p>
      <label htmlFor="sheet-language" className="sr-only">
        {t("settings.sheetLanguageSr")}
      </label>
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
        className="mt-3 h-12 w-full rounded-button bg-surface-muted px-4 text-[15px] font-medium text-ink outline-none"
      >
        {CONTENT_LANGUAGES.map((code) => (
          <option key={code} value={code}>
            {LANGUAGE_LABELS[code]}
          </option>
        ))}
      </select>
      <p className="mt-3 text-[13px] leading-relaxed text-ink-tertiary">
        {t("settings.sheetLanguageHelp")}
      </p>
    </section>
  );
}
