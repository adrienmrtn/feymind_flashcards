"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";

import { setUiLocale } from "@/lib/actions/locale";
import { useI18n } from "@/lib/i18n/client";
import { UI_LOCALES, UI_LOCALE_META, type UiLocale } from "@/lib/i18n/locales";

/**
 * La langue du site. Pas un drapeau : une langue n'est pas un pays.
 *
 * Compact dans une barre, large dans les réglages. Les noms restent dans
 * leur langue, pour qu'on se reconnaisse avant d'avoir tout lu.
 */
export function LanguageSwitcher({
  variant = "compact",
}: {
  variant?: "compact" | "card";
}) {
  const { locale, t } = useI18n();
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  function pick(next: UiLocale) {
    if (next === locale || pending) return;
    startTransition(async () => {
      await setUiLocale(next);
      router.refresh();
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
              onClick={() => pick(code)}
              disabled={pending}
              aria-pressed={code === locale}
              className={`pressable min-h-11 rounded-button px-3 text-[14px] font-medium leading-tight ${
                code === locale
                  ? "bg-accent-soft text-accent"
                  : "bg-surface-muted text-ink shadow-[inset_0_0_0_1px_var(--color-stroke-strong)]"
              }`}
            >
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

  return (
    <label className="relative inline-flex min-h-11 min-w-0 items-center">
      <span className="sr-only">{t("locale.switcher")}</span>
      <select
        value={locale}
        disabled={pending}
        onChange={(event) => pick(event.target.value as UiLocale)}
        className="max-w-[7.5rem] truncate rounded-button bg-transparent py-1.5 pe-7 ps-2 text-[13px] font-medium text-ink-secondary outline-none sm:max-w-[11rem]"
        aria-label={t("locale.switcher")}
      >
        {UI_LOCALES.map((code) => (
          <option key={code} value={code}>
            {UI_LOCALE_META[code].native}
          </option>
        ))}
      </select>
    </label>
  );
}
