"use client";

import Link from "next/link";
import type { Route } from "next";

import { examUrgency, type ExamInsight } from "@micabo/core";

import { useI18n } from "@/lib/i18n/client";
import { copyExamCountdown } from "@/lib/i18n/copy";

/**
 * La carte d'un examen : la note visée d'abord, puis l'avancée et les points
 * faibles. Les courbes ont disparu : elles demandaient à être lues, et ce
 * qu'on vient chercher est le chiffre.
 */
export function ExamInsightCard({
  insight,
  href,
  onClick,
}: {
  insight: ExamInsight;
  href?: Route;
  onClick?: () => void;
}) {
  const { t } = useI18n();
  const inner = <InsightBody insight={insight} />;
  const label = `${insight.name}, ${t("app.exams.targetGrade")} ${insight.gradeLabel}, ${copyExamCountdown(t, insight.daysRemaining)}`;

  if (href) {
    return (
      <Link
        href={href}
        aria-label={label}
        className="block min-w-0 max-w-full overflow-hidden rounded-2xl border border-border bg-card p-4 text-left shadow-xs/5 sm:p-5"
      >
        {inner}
      </Link>
    );
  }

  if (onClick) {
    return (
      <button
        type="button"
        onClick={onClick}
        aria-label={label}
        className="w-full min-w-0 max-w-full overflow-hidden rounded-2xl border border-border bg-card p-4 text-left shadow-xs/5 sm:p-5"
      >
        {inner}
      </button>
    );
  }

  return (
    <article className="min-w-0 max-w-full overflow-hidden rounded-2xl border border-border bg-card p-4 shadow-xs/5 sm:p-5">
      {inner}
    </article>
  );
}

function InsightBody({ insight }: { insight: ExamInsight }) {
  const { t } = useI18n();
  const urgency = examUrgency(insight.daysRemaining);
  const tone =
    urgency === "critical"
      ? "bg-negative-soft text-negative"
      : urgency === "soon"
        ? "bg-caution-soft text-caution"
        : urgency === "upcoming"
          ? "bg-info-soft text-info"
          : "bg-surface-muted text-ink-secondary";

  return (
    <div className="flex h-full min-w-0 flex-col">
      <div className="flex min-w-0 items-start justify-between gap-2 sm:gap-3">
        <p className="min-w-0 truncate text-[17px] font-semibold leading-tight text-ink sm:text-[18px]">
          {insight.name}
        </p>
        <span
          className={`max-w-[48%] shrink-0 truncate rounded-pill px-2 py-0.5 text-[11.5px] font-bold tracking-caps ${tone}`}
        >
          {copyExamCountdown(t, insight.daysRemaining)}
        </span>
      </div>

      <p className="numeral mt-4 text-[32px] font-bold leading-none text-ink sm:mt-5 sm:text-[40px]">
        {insight.gradeLabel}
      </p>
      <p className="mt-1.5 text-[13px] text-ink-tertiary">{t("app.exams.targetGrade")}</p>

      <p className="mt-5 text-[13px] font-medium text-ink">
        {t("app.exams.learnedPct", { pct: insight.learnedPct })}
      </p>
      <div className="mt-1.5 h-1.5 overflow-hidden rounded-pill bg-progress-track">
        <div
          className="h-full rounded-pill bg-progress"
          style={{ width: `${insight.learnedPct}%` }}
        />
      </div>

      <p className="mt-5 text-[10px] font-bold uppercase tracking-caps text-ink-tertiary">
        {t("app.exams.weakPoints")}
      </p>
      {insight.weak.length === 0 ? (
        <p className="mt-2 text-[13px] leading-relaxed text-ink-secondary">
          {insight.cardCount === 0
            ? t("app.exams.weakEmpty.noCourse")
            : t("app.exams.weakEmpty.clear")}
        </p>
      ) : (
        <ul className="mt-2 min-w-0 divide-y divide-hairline">
          {insight.weak.map((card) => (
            <li key={card.id} className="flex min-w-0 items-center gap-2 py-2 first:pt-0 last:pb-0">
              <span className="shrink-0 rounded-pill bg-caution-soft px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-caps text-caution">
                {card.kindLabel}
              </span>
              <span className="min-w-0 flex-1 truncate text-[13px] font-medium text-ink">
                {card.prompt}
              </span>
              <span className="max-w-[40%] shrink-0 truncate text-[11.5px] text-ink-tertiary">
                {card.note}
              </span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
