"use client";

import { useTransition } from "react";

import { setUiLocale } from "@/lib/actions/locale";
import { useI18n } from "@/lib/i18n/client";
import { UI_LOCALES, UI_LOCALE_META, type UiLocale } from "@/lib/i18n/locales";

/**
 * La langue du site. Les drapeaux se lisent avant les noms.
 *
 * Compact dans une barre, drapeaux sur l'accueil, large dans les réglages.
 * Les noms restent dans leur langue, pour qu'on se reconnaisse avant d'avoir tout lu.
 */
export function LanguageSwitcher({
  variant = "compact",
}: {
  variant?: "compact" | "card" | "flags";
}) {
  const { locale, t, pick } = useI18n();
  const [pending, startTransition] = useTransition();

  function choose(next: UiLocale) {
    if (next === locale || pending) return;
    pick(next);
    startTransition(async () => {
      await setUiLocale(next);
    });
  }

  if (variant === "card") {
    return (
      <section className="saas-card p-7">
        <p className="text-[13px] text-ink-tertiary">{t("settings.siteLanguage")}</p>
        <div className="mt-3 grid grid-cols-2 gap-2">
          {UI_LOCALES.map((code) => (
            <button
              key={code}
              type="button"
              onClick={() => choose(code)}
              disabled={pending}
              aria-pressed={code === locale}
              aria-label={UI_LOCALE_META[code].native}
              className={`pressable flex min-h-11 items-center justify-center gap-2 rounded-button px-3 text-[14px] font-medium leading-tight ${
                code === locale
                  ? "bg-accent-soft text-accent"
                  : "bg-surface-muted text-ink shadow-[inset_0_0_0_1px_var(--color-stroke-strong)]"
              }`}
            >
              <span aria-hidden className="text-[18px] leading-none">
                {UI_LOCALE_META[code].flag}
              </span>
              {UI_LOCALE_META[code].native}
            </button>
          ))}
        </div>
        <p className="mt-3 text-[13px] leading-relaxed text-ink-tertiary">
          {t("settings.siteLanguageHelp")}
        </p>
      </section>
    );
  }

  if (variant === "flags") {
    return (
      <div role="group" aria-label={t("locale.switcher")} className="w-full">
        <p className="text-center text-[13px] font-medium text-ink-tertiary">{t("locale.choose")}</p>
        <div className="mt-2 grid grid-cols-4 gap-2">
          {UI_LOCALES.map((code) => (
            <button
              key={code}
              type="button"
              onClick={() => choose(code)}
              disabled={pending}
              aria-pressed={code === locale}
              aria-label={UI_LOCALE_META[code].native}
              className={`pressable flex min-h-16 flex-col items-center justify-center gap-1.5 rounded-button px-1.5 py-2.5 text-[11.5px] font-medium leading-tight ${
                code === locale
                  ? "bg-accent-soft text-accent shadow-[inset_0_0_0_1.5px_var(--color-accent)]"
                  : "bg-surface-muted text-ink shadow-[inset_0_0_0_1px_var(--color-stroke-strong)]"
              }`}
            >
              <span aria-hidden className="text-[28px] leading-none">
                {UI_LOCALE_META[code].flag}
              </span>
              {UI_LOCALE_META[code].native}
            </button>
          ))}
        </div>
      </div>
    );
  }

  return (
    <label className="relative inline-flex min-h-11 min-w-0 items-center">
      <span className="sr-only">{t("locale.switcher")}</span>
      <select
        value={locale}
        disabled={pending}
        onChange={(event) => choose(event.target.value as UiLocale)}
        className="max-w-[9.5rem] truncate rounded-button bg-transparent py-1.5 pe-7 ps-2 text-[13px] font-medium text-ink-secondary outline-none sm:max-w-[12rem]"
        aria-label={t("locale.switcher")}
      >
        {UI_LOCALES.map((code) => (
          <option key={code} value={code}>
            {UI_LOCALE_META[code].flag} {UI_LOCALE_META[code].native}
          </option>
        ))}
      </select>
    </label>
  );
}
