"use client";

import { SettingsRow } from "@/components/app/settings/Rows";
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
export function AppearanceSwitcher({ variant = "row" }: { variant?: "row" | "compact" }) {
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

  // Trois tuiles empilées dans une carte pour un choix à trois valeurs : c'est un segmenté,
  // et un segmenté tient sur une ligne.
  return (
    <SettingsRow label={t("settings.appearance")} hint={t("settings.appearanceHelp")}>
      <div
        role="group"
        aria-label={t("settings.appearance")}
        className="grid grid-cols-3 gap-1 rounded-button bg-surface-muted p-1"
      >
        {APPEARANCES.map((value) => (
          <button
            key={value}
            type="button"
            onClick={() => setAppearance(value)}
            aria-pressed={value === appearance}
            className={`pressable flex h-9 items-center justify-center gap-2 rounded-[calc(var(--radius-button)-3px)] text-[13.5px] font-medium transition-colors duration-hover ${
              value === appearance ? "bg-surface text-ink shadow-paper" : "text-ink-secondary"
            }`}
          >
            <span
              aria-hidden
              className="block size-3.5 rounded-full border border-stroke-strong"
              style={{ background: SWATCH[value] }}
            />
            {t(LABEL_KEY[value])}
          </button>
        ))}
      </div>
    </SettingsRow>
  );
}
