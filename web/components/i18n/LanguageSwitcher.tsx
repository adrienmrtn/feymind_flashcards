"use client";

import { useTransition } from "react";
import { usePathname, useRouter } from "next/navigation";

import { ROW_FIELD, SettingsRow } from "@/components/app/settings/Rows";
import { setUiLocale } from "@/lib/actions/locale";
import { useI18n } from "@/lib/i18n/client";
import { UI_LOCALES, UI_LOCALE_META, type UiLocale } from "@/lib/i18n/locales";
import { localeSwitchHref } from "@/lib/i18n/paths";

/**
 * La langue du site. Les drapeaux se lisent avant les noms.
 *
 * Compact dans une barre, large dans les réglages.
 * Les noms restent dans leur langue, pour qu'on se reconnaisse avant d'avoir tout lu.
 */
export function LanguageSwitcher({
  variant = "compact",
}: {
  variant?: "compact" | "row";
}) {
  const { locale, t, pick } = useI18n();
  const router = useRouter();
  const pathname = usePathname();
  const [pending, startTransition] = useTransition();

  function choose(next: UiLocale) {
    if (next === locale || pending) return;
    pick(next);
    startTransition(async () => {
      await setUiLocale(next);
      const target = localeSwitchHref(pathname, next);
      if (target) {
        // `router.push` ne suffit pas : `/tr/methode` est déjà réécrit en
        // `/methode`, le cache RSC sert encore le turc. L'adresse doit
        // recharger, sinon titres et corps ne sont plus la même langue.
        window.location.assign(target);
        return;
      }
      router.refresh();
    });
  }

  // Cinq gros boutons à drapeau tenaient une carte entière pour un réglage qu'on touche
  // une fois. Dans une ligne, la liste déroulante dit la même chose sur un dixième de la
  // hauteur, et le drapeau reste devant le nom.
  if (variant === "row") {
    return (
      <SettingsRow
        label={t("settings.siteLanguage")}
        htmlFor="site-language"
        hint={t("settings.siteLanguageHelp")}
        control={
          <select
            id="site-language"
            value={locale}
            disabled={pending}
            onChange={(event) => choose(event.target.value as UiLocale)}
            className={`${ROW_FIELD} w-[15rem] max-w-full font-medium`}
          >
            {UI_LOCALES.map((code) => (
              <option key={code} value={code}>
                {UI_LOCALE_META[code].flag} {UI_LOCALE_META[code].native}
              </option>
            ))}
          </select>
        }
      />
    );
  }

  return (
    <label className="relative inline-flex min-h-11 min-w-0 items-center">
      <span className="sr-only">{t("locale.switcher")}</span>
      <select
        value={locale}
        disabled={pending}
        onChange={(event) => choose(event.target.value as UiLocale)}
        className="max-w-[4.25rem] truncate rounded-button bg-transparent py-1.5 pe-7 ps-2 text-[13px] font-medium text-ink-secondary outline-none sm:max-w-[12rem]"
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
