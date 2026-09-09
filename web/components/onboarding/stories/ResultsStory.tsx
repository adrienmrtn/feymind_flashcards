"use client";

import { useEffect, useState } from "react";

import { useI18n } from "@/lib/i18n/client";

/**
 * La vignette des résultats : **avant, après.**
 *
 * Deux barres, et le chiffre entre les deux. C'est le seul écran du parcours qui avance une
 * mesure, donc il ne doit avancer que celle-là : ni courbe à trois séries, ni axe à graduer.
 * Les barres montent à l'arrivée sur l'écran, parce qu'un écart se lit dans le mouvement bien
 * avant de se lire dans les chiffres.
 */
export function ResultsStory() {
  const { t } = useI18n();
  const [grown, setGrown] = useState(false);

  useEffect(() => {
    const id = window.setTimeout(() => setGrown(true), 220);
    return () => window.clearTimeout(id);
  }, []);

  // Les deux valeurs viennent du catalogue : une moyenne sur 20 ne veut rien dire pour un
  // étudiant américain, et un pourcentage n'en veut aucun pour un Français.
  const bars = [
    {
      label: t("onboarding.resultatsBefore"),
      height: 52,
      tone: "var(--color-stroke-strong)",
      value: t("onboarding.resultatsBeforeValue"),
    },
    {
      label: t("onboarding.resultatsAfter"),
      height: 100,
      tone: "var(--color-accent)",
      value: t("onboarding.resultatsAfterValue"),
    },
  ];

  return (
    <div className="w-full max-w-[320px]">
      <div className="flex h-[190px] items-end justify-center gap-10">
        {bars.map((bar, index) => (
          <div key={bar.label} className="flex w-[84px] flex-col items-center">
            <span
              className="numeral text-[14px] font-semibold text-ink transition-opacity duration-slow"
              style={{ opacity: grown ? 1 : 0, transitionDelay: `${420 + index * 120}ms` }}
            >
              {bar.value}
            </span>
            <span className="mt-2 flex h-[130px] w-full items-end">
              <span
                aria-hidden
                className="w-full rounded-t-[10px]"
                style={{
                  height: grown ? `${bar.height}%` : "6%",
                  backgroundColor: bar.tone,
                  transition: "height 900ms var(--ease-out-strong)",
                  transitionDelay: `${index * 140}ms`,
                }}
              />
            </span>
            <span className="mt-2.5 text-center text-[11.5px] leading-tight text-ink-tertiary">
              {bar.label}
            </span>
          </div>
        ))}
      </div>

      <p
        className="mt-4 text-center text-[13px] text-ink-tertiary transition-opacity duration-slow"
        style={{ opacity: grown ? 1 : 0, transitionDelay: "700ms" }}
      >
        {t("onboarding.resultatsCaption")}
      </p>
    </div>
  );
}
