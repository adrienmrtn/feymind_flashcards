"use client";

import { useI18n } from "@/lib/i18n/client";

/**
 * Où en est la préparation : un seul trait, deux repères.
 *
 * Deux pourcentages géants côte à côte se lisaient comme deux notes. Ici c'est une même
 * échelle : ce qui est su aujourd'hui en plein, ce que le plan promet pour le jour J en
 * clair, et l'objectif en trait fin s'il y en a un.
 */
export function ReadinessBar({
  now,
  projected,
  target,
  measured = false,
}: {
  now: number;
  projected: number;
  target?: number | null;
  measured?: boolean;
}) {
  const { t } = useI18n();
  const current = clamp(now);
  const later = Math.max(current, clamp(projected));

  return (
    <div>
      <div className="flex items-baseline justify-between gap-3">
        <p className="flex items-baseline gap-1.5">
          <span className="hero-value">{current}<span className="text-[20px] text-ink-secondary"> %</span></span>
          <span className="text-[12.5px] text-ink-tertiary">
            {measured ? t("app.chart.readiness.measured") : t("app.chart.readiness.now")}
          </span>
        </p>
        <p className="text-right text-[12.5px] text-ink-secondary">
          <span className="numeral text-[15px] font-semibold text-ink">{later} %</span>{" "}
          {t("app.chart.readiness.day")}
        </p>
      </div>
      <div
        className="relative mt-3 h-2.5 w-full rounded-full"
        style={{ backgroundColor: "var(--color-surface-sunken)" }}
        role="img"
        aria-label={t("app.chart.readiness.aria", { now: current, projected: later })}
      >
        <span
          aria-hidden
          className="absolute inset-y-0 left-0 rounded-full"
          style={{ width: `${later}%`, backgroundColor: "var(--chart-work-soft)" }}
        />
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
