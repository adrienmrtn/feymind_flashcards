import Link from "next/link";
import type { Route } from "next";

import {
  examCountdownLabel,
  examUrgency,
  type ExamInsight,
} from "@micabo/core";

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
  const inner = <InsightBody insight={insight} />;
  const label = `${insight.name}, note visée ${insight.gradeLabel}, ${examCountdownLabel(insight.daysRemaining)}`;

  if (href) {
    return (
      <Link
        href={href}
        aria-label={label}
        className="block rounded-2xl border border-border bg-card p-5 text-left shadow-xs/5"
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
        className="w-full rounded-2xl border border-border bg-card p-5 text-left shadow-xs/5"
      >
        {inner}
      </button>
    );
  }

  return <article className="rounded-2xl border border-border bg-card p-5 shadow-xs/5">{inner}</article>;
}

function InsightBody({ insight }: { insight: ExamInsight }) {
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
    <div className="flex h-full flex-col">
      <div className="flex items-start justify-between gap-3">
        <p className="min-w-0 truncate text-[17px] font-semibold leading-tight text-ink sm:text-[18px]">
          {insight.name}
        </p>
        <span className={`shrink-0 rounded-pill px-2 py-0.5 text-[11.5px] font-bold tracking-caps ${tone}`}>
          {examCountdownLabel(insight.daysRemaining)}
        </span>
      </div>

      <p className="numeral mt-5 text-[40px] font-bold leading-none text-ink">
        {insight.gradeLabel}
      </p>
      <p className="mt-1.5 text-[13px] text-ink-tertiary">Note visée</p>

      <p className="mt-5 text-[13px] font-medium text-ink">
        Cours appris à{" "}
        <span className="numeral font-bold text-accent">{insight.learnedPct}%</span>
      </p>
      <div className="mt-1.5 h-1.5 overflow-hidden rounded-pill bg-progress-track">
        <div
          className="h-full rounded-pill bg-progress"
          style={{ width: `${insight.learnedPct}%` }}
        />
      </div>

      <p className="mt-5 text-[10px] font-bold uppercase tracking-caps text-ink-tertiary">
        Tes points faibles
      </p>
      {insight.weak.length === 0 ? (
        <p className="mt-2 text-[13px] leading-relaxed text-ink-secondary">
          {insight.cardCount === 0
            ? "Relie un cours pour voir tes points faibles."
            : "Rien à signaler pour l'instant."}
        </p>
      ) : (
        <ul className="mt-2 divide-y divide-hairline">
          {insight.weak.map((card) => (
            <li key={card.id} className="flex items-center gap-2 py-2 first:pt-0 last:pb-0">
              <span className="shrink-0 rounded-pill bg-caution-soft px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-caps text-caution">
                {card.kindLabel}
              </span>
              <span className="min-w-0 flex-1 truncate text-[13px] font-medium text-ink">
                {card.prompt}
              </span>
              <span className="shrink-0 text-[11.5px] text-ink-tertiary">{card.note}</span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
