"use client";

import { SettingsRow } from "@/components/app/settings/Rows";
import { type Appearance } from "@/lib/appearance";
import { useI18n } from "@/lib/i18n/client";

import { useAppearance } from "./AppearanceProvider";

const SWATCH: Record<Appearance, string> = {
  day: "#eef1f8",
  night: "#0b0f1c",
  twilight: "#0b0f1c",
};

/** Les deux thèmes de l'app (V3.3) : le marine, puis le clair. Le crépuscule s'affiche en
 *  marine et n'est plus proposé. */
const CHOICES: readonly Appearance[] = ["night", "day"];

const LABEL_KEY: Record<Appearance, "settings.appearanceDay" | "settings.appearanceNight" | "settings.appearanceTwilight"> =
  {
    day: "settings.appearanceDay",
    night: "settings.appearanceNight",
    twilight: "settings.appearanceTwilight",
  };

/**
 * Marine ou clair. Large dans les réglages, compact dans la barre.
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
        {CHOICES.map((value) => (
          <button
            key={value}
            type="button"
            onClick={() => setAppearance(value)}
            aria-pressed={(value === appearance || (value === "night" && appearance === "twilight"))}
            aria-label={t(LABEL_KEY[value])}
            className={`pressable flex size-7 items-center justify-center rounded-full ${
              (value === appearance || (value === "night" && appearance === "twilight")) ? "ring-2 ring-accent ring-offset-2 ring-offset-background" : ""
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
        className="grid grid-cols-2 gap-1 rounded-button bg-surface-muted p-1"
      >
        {CHOICES.map((value) => (
          <button
            key={value}
            type="button"
            onClick={() => setAppearance(value)}
            aria-pressed={(value === appearance || (value === "night" && appearance === "twilight"))}
            className={`pressable flex h-9 items-center justify-center gap-2 rounded-[calc(var(--radius-button)-3px)] text-[13.5px] font-medium transition-colors duration-hover ${
              (value === appearance || (value === "night" && appearance === "twilight")) ? "bg-surface text-ink shadow-paper" : "text-ink-secondary"
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
