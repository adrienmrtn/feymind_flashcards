"use client";

import { useI18n } from "@/lib/i18n/client";

/**
 * Où en est la préparation : un seul trait, un repère.
 *
 * **La projection « x % le jour J » est partie.** Elle sortait d'une formule - un gain à
 * rendement décroissant par passage prévu - et elle s'affichait comme une mesure, à côté d'un
 * pourcentage qui, lui, est compté sur des cartes réelles. Deux nombres de même forme dont un
 * seul est vrai : l'étudiant lisait une promesse et croyait lire un relevé. Et la promesse
 * n'était actionnable en rien, puisqu'elle bougeait avec le plan et pas avec le travail.
 *
 * Reste ce qui se mesure : ce qui est su aujourd'hui, et l'objectif en trait fin s'il y en a
 * un. C'est la seule chose qu'on puisse dire sans se tromper, et c'est celle qui bouge quand
 * on révise.
 */
export function ReadinessBar({
  now,
  target,
  measured = false,
}: {
  now: number;
  target?: number | null;
  measured?: boolean;
}) {
  const { t } = useI18n();
  const current = clamp(now);

  return (
    <div>
      <p className="flex items-baseline gap-1.5">
        <span className="hero-value">
          {current}
          <span className="text-[20px] text-ink-secondary"> %</span>
        </span>
        <span className="text-[12.5px] text-ink-tertiary">
          {measured ? t("app.chart.readiness.measured") : t("app.chart.readiness.now")}
        </span>
      </p>
      <div
        className="relative mt-3 h-2.5 w-full rounded-full"
        style={{ backgroundColor: "var(--color-surface-sunken)" }}
        role="img"
        aria-label={t("app.chart.readiness.aria", { now: current })}
      >
        <span
          aria-hidden
          className="absolute inset-y-0 left-0 rounded-full"
          style={{ width: `${current}%`, backgroundColor: "var(--chart-work)" }}
        />
        {target != null ? (
          <span
            aria-hidden
            className="absolute -inset-y-1 w-[2px] rounded-full bg-ink"
            style={{ left: `calc(${clamp(target)}% - 1px)` }}
            title={t("app.chart.readiness.target", { percent: clamp(target) })}
          />
        ) : null}
      </div>
      {target != null ? (
        <p className="numeral mt-1.5 text-[11.5px] text-ink-tertiary" style={{ marginLeft: `min(calc(${clamp(target)}% - 24px), calc(100% - 80px))` }}>
          {t("app.chart.readiness.target", { percent: clamp(target) })}
        </p>
      ) : null}
    </div>
  );
}

function clamp(value: number): number {
  return Math.max(0, Math.min(100, Math.round(value)));
}
