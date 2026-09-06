"use client";

import { APPEARANCES, type Appearance } from "@/lib/appearance";
import { useI18n } from "@/lib/i18n/client";

import { useAppearance } from "./AppearanceProvider";

const SWATCH: Record<Appearance, string> = {
  day: "#f6f7f9",
  night: "#101216",
  twilight: "#2a211b",
};

const LABEL_KEY: Record<Appearance, "settings.appearanceDay" | "settings.appearanceNight" | "settings.appearanceTwilight"> =
  {
    day: "settings.appearanceDay",
    night: "settings.appearanceNight",
    twilight: "settings.appearanceTwilight",
  };

/**
 * Jour, nuit, crépuscule. Large dans les réglages, compact dans la barre.
 */
export function AppearanceSwitcher({ variant = "card" }: { variant?: "card" | "compact" }) {
  const { t } = useI18n();
  const { appearance, setAppearance } = useAppearance();

  if (variant === "compact") {
    return (
      <div
        role="group"
        aria-label={t("settings.appearance")}
        className="flex items-center gap-1 rounded-pill bg-surface-muted p-1"
      >
        {APPEARANCES.map((value) => (
          <button
            key={value}
            type="button"
            onClick={() => setAppearance(value)}
            aria-pressed={value === appearance}
            aria-label={t(LABEL_KEY[value])}
            className={`pressable flex size-7 items-center justify-center rounded-full ${
              value === appearance ? "ring-2 ring-accent ring-offset-2 ring-offset-background" : ""
            }`}
          >
            <span
              aria-hidden
              className="block size-4 rounded-full border border-stroke-strong"
              style={{ background: SWATCH[value] }}
            />
          </button>
        ))}
      </div>
    );
  }

  return (
    <section className="saas-card p-7">
      <p className="text-[13px] text-ink-tertiary">{t("settings.appearance")}</p>
      <div className="mt-3 grid grid-cols-3 gap-2">
        {APPEARANCES.map((value) => (
          <button
            key={value}
            type="button"
            onClick={() => setAppearance(value)}
            aria-pressed={value === appearance}
            className={`pressable flex min-h-11 flex-col items-center justify-center gap-1.5 rounded-button px-2 py-2.5 text-[13.5px] font-medium leading-tight ${
              value === appearance
                ? "bg-accent-soft text-accent"
                : "bg-surface-muted text-ink shadow-[inset_0_0_0_1px_var(--color-stroke-strong)]"
            }`}
          >
            <span
              aria-hidden
              className="block size-4 rounded-full border border-stroke-strong"
              style={{ background: SWATCH[value] }}
            />
            {t(LABEL_KEY[value])}
          </button>
        ))}
      </div>
      <p className="mt-3 text-[13px] leading-relaxed text-ink-tertiary">
        {t("settings.appearanceHelp")}
      </p>
    </section>
  );
}
