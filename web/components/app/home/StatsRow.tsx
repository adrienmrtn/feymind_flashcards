"use client";

import type { DailyReview, StudyStats } from "@micabo/core";

import { useI18n } from "@/lib/i18n/client";

/**
 * Quatre chiffres, et une courbe qui les explique.
 *
 * Le tableau de bord n'en montrait aucun : il comptait des cartes dues, ce qui est une file
 * d'attente et pas une mesure. Les quatre retenus répondent chacun à une question distincte -
 * combien j'ai travaillé, est-ce que ça marche, est-ce que je tiens, quel est mon meilleur
 * jour. Un cinquième n'apporterait rien qu'on ne puisse déduire de ceux-là.
 *
 * **La justesse est la seule vraiment nouvelle.** C'est elle qui rend les points faibles
 * lisibles : un étudiant à 62 % comprend pourquoi les mêmes cartes lui reviennent sans arrêt.
 */
export function StatsRow({
  stats,
  daily,
}: {
  stats: StudyStats;
  daily: DailyReview[];
}) {
  const { t } = useI18n();
  const recent = daily.slice(-42);

  return (
    <section className="rounded-group border border-border bg-card p-5" data-tour="statistiques">
      <h2 className="text-[15px] font-semibold text-ink">{t("app.home.stats.title")}</h2>

      <dl className="mt-4 grid grid-cols-2 gap-4 sm:grid-cols-4">
        <Stat
          label={t("app.home.stats.passes")}
          value={stats.totalPasses.toLocaleString()}
          detail={t("app.home.stats.passesDetail", { days: stats.activeDays })}
        />
        <Stat
          label={t("app.home.stats.accuracy")}
          value={`${stats.accuracyPercent} %`}
          detail={t("app.home.stats.accuracyDetail")}
        />
        <Stat
          label={t("app.home.stats.streak")}
          value={`${stats.streak}`}
          detail={t("app.home.stats.streakDetail", { best: stats.bestStreak })}
        />
        <Stat
          label={t("app.home.stats.average")}
          value={`${stats.averagePasses}`}
          detail={
            stats.best
              ? t("app.home.stats.averageDetail", { best: stats.best.passes })
              : t("app.home.stats.averageEmpty")
          }
        />
      </dl>

      {recent.length > 1 ? (
        <div className="mt-5">
          <div className="flex h-14 items-end gap-[3px]" role="img" aria-label={t("app.home.stats.chartAria")}>
            {recent.map((point) => {
              const max = Math.max(1, ...recent.map((entry) => entry.passes));
              const height = Math.max(2, Math.round((point.passes / max) * 100));
              const failed = point.passes === 0 ? 0 : point.againCount / point.passes;
              return (
                <span
                  key={point.day.toISOString()}
                  aria-hidden
                  title={t("app.home.stats.chartDay", {
                    passes: point.passes,
                    again: point.againCount,
                  })}
                  className={`min-w-0 flex-1 rounded-t-[2px] ${
                    failed > 0.35 ? "bg-caution" : "bg-accent"
                  }`}
                  style={{ height: `${height}%` }}
                />
              );
            })}
          </div>
          <p className="mt-2 text-[12px] text-ink-tertiary">{t("app.home.stats.chartLegend")}</p>
        </div>
      ) : null}
    </section>
  );
}

function Stat({
  label,
  value,
  detail,
}: {
  label: string;
  value: string;
  detail: string;
}) {
  return (
    <div className="min-w-0">
      <dt className="truncate text-[12.5px] text-ink-tertiary">{label}</dt>
      <dd className="numeral mt-1 text-[24px] font-bold leading-none tracking-tight text-ink">
        {value}
      </dd>
      <p className="mt-1 truncate text-[12px] text-ink-tertiary">{detail}</p>
    </div>
  );
}
