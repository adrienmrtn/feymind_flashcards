"use client";

import { useEffect, useRef, useState } from "react";

import { useI18n } from "@/lib/i18n/client";

/**
 * La vignette des résultats : **la courbe qui monte.**
 *
 * C'étaient deux barres, avant et après. Deux barres disent qu'il s'est passé quelque chose,
 * elles ne disent pas quoi : on saute d'un état à l'autre sans rien voir entre les deux, et
 * c'est exactement ce qu'un étudiant veut savoir - à quoi ressemblent les semaines.
 *
 * Donc une courbe, et **une courbe imparfaite** : elle redescend trois fois. Une droite
 * parfaite de 74 à 91 se lit comme une promesse commerciale ; un tracé qui bute et repart se
 * lit comme un semestre. Le trait se dessine à l'arrivée sur l'écran, de gauche à droite,
 * parce que c'est le sens de la lecture et le sens du temps.
 */

/** La note, semaine après semaine. Elle finit à 91, elle n'y va pas tout droit. */
const SERIES = [74, 76, 75, 79, 82, 80, 84, 87, 86, 89, 91] as const;

const WIDTH = 320;
const HEIGHT = 150;
const PADDING = { top: 14, right: 10, bottom: 10, left: 10 };
/** L'échelle verticale déborde des valeurs : une courbe qui touche les bords se lit mal. */
const FLOOR = 68;
const CEILING = 96;

export function ResultsStory() {
  const { t } = useI18n();
  const [drawn, setDrawn] = useState(false);
  const line = useRef<SVGPolylineElement>(null);
  const [length, setLength] = useState(0);

  useEffect(() => {
    if (line.current) setLength(line.current.getTotalLength());
    const id = window.setTimeout(() => setDrawn(true), 180);
    return () => window.clearTimeout(id);
  }, []);

  const points = SERIES.map((value, index) => {
    const span = SERIES.length - 1;
    const x = PADDING.left + ((WIDTH - PADDING.left - PADDING.right) * index) / span;
    const ratio = (value - FLOOR) / (CEILING - FLOOR);
    const y = HEIGHT - PADDING.bottom - (HEIGHT - PADDING.top - PADDING.bottom) * ratio;
    return { x, y };
  });

  const path = points.map((point) => `${point.x},${point.y}`).join(" ");
  const area = `${PADDING.left},${HEIGHT} ${path} ${points[points.length - 1]!.x},${HEIGHT}`;
  const last = points[points.length - 1]!;

  return (
    <div className="w-full max-w-[320px]">
      <div className="flex items-baseline justify-between">
        <span className="text-[11.5px] text-ink-tertiary">{t("onboarding.resultatsBefore")}</span>
        <span className="text-[11.5px] text-ink-tertiary">{t("onboarding.resultatsAfter")}</span>
      </div>

      <div className="relative mt-1.5">
        <svg
          viewBox={`0 0 ${WIDTH} ${HEIGHT}`}
          className="w-full"
          role="img"
          aria-label={t("onboarding.resultatsChartAria")}
        >
          <defs>
            <linearGradient id="resultats-fill" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="var(--color-accent)" stopOpacity="0.22" />
              <stop offset="100%" stopColor="var(--color-accent)" stopOpacity="0" />
            </linearGradient>
          </defs>

          <polygon
            points={area}
            fill="url(#resultats-fill)"
            className="transition-opacity duration-slower"
            style={{ opacity: drawn ? 1 : 0, transitionDelay: "520ms" }}
          />

          <polyline
            ref={line}
            points={path}
            fill="none"
            stroke="var(--color-accent)"
            strokeWidth="2.6"
            strokeLinecap="round"
            strokeLinejoin="round"
            style={{
              strokeDasharray: length || 600,
              strokeDashoffset: drawn ? 0 : length || 600,
              transition: "stroke-dashoffset 1400ms var(--ease-out-strong)",
            }}
          />

          <circle
            cx={last.x}
            cy={last.y}
            r="4.5"
            fill="var(--color-accent)"
            className="transition-opacity duration-slow"
            style={{ opacity: drawn ? 1 : 0, transitionDelay: "1250ms" }}
          />
        </svg>

        <span
          className="numeral absolute left-0 top-0 text-[13px] font-semibold text-ink-tertiary transition-opacity duration-slow"
          style={{ opacity: drawn ? 1 : 0, transitionDelay: "260ms" }}
        >
          {t("onboarding.resultatsBeforeValue")}
        </span>
        <span
          className="numeral absolute right-0 top-0 text-[15px] font-bold text-accent transition-opacity duration-slow"
          style={{ opacity: drawn ? 1 : 0, transitionDelay: "1300ms" }}
        >
          {t("onboarding.resultatsAfterValue")}
        </span>
      </div>

      <p
        className="mt-2 text-center text-[13px] text-ink-tertiary transition-opacity duration-slow"
        style={{ opacity: drawn ? 1 : 0, transitionDelay: "1400ms" }}
      >
        {t("onboarding.resultatsCaption")}
      </p>
    </div>
  );
}
