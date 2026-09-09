"use client";

import { useI18n } from "@/lib/i18n/client";
import { localeBcp47 } from "@/lib/i18n/copy";

import { SrTable } from "./primitives";
import { useMeasuredWidth } from "./useMeasuredWidth";

/**
 * Les scores des blancs, dans l'ordre où ils ont été passés.
 *
 * C'est une suite, pas une liste : 54 puis 71 dit que la correction a pris, 54 puis 52 dit
 * qu'il faut changer de méthode. Une ligne le montre, une liste de barres ne le montrait pas.
 */
export interface MockPoint {
  id: string;
  score: number;
  questionCount: number;
  /** AAAA-MM-JJ */
  finishedAt: string;
}

const H = 120;
const PAD = { top: 12, right: 28, bottom: 22, left: 30 };

export function MockTrend({ points, target }: { points: MockPoint[]; target?: number | null }) {
  const { t, locale } = useI18n();
  const bcp = localeBcp47(locale as never);
  const ordered = [...points].sort((left, right) => (left.finishedAt < right.finishedAt ? -1 : 1));
  const { ref, width: W } = useMeasuredWidth<HTMLDivElement>(420);
  if (ordered.length === 0) return null;

  const plotW = W - PAD.left - PAD.right;
  const plotH = H - PAD.top - PAD.bottom;
  const x = (index: number) =>
    PAD.left + (ordered.length === 1 ? plotW / 2 : (index / (ordered.length - 1)) * plotW);
  const y = (score: number) => PAD.top + plotH - (Math.max(0, Math.min(100, score)) / 100) * plotH;
  const path = ordered.map((point, index) => `${index === 0 ? "M" : "L"} ${x(index)} ${y(point.score)}`).join(" ");
  const last = ordered[ordered.length - 1]!;
  const dateLabel = (iso: string) =>
    new Date(`${iso}T12:00:00`).toLocaleDateString(bcp, { day: "numeric", month: "short" });

  return (
    <div ref={ref} className="max-w-[480px]">
      <svg viewBox={`0 0 ${W} ${H}`} width={W} height={H} className="block max-w-full" role="img" aria-label={t("app.chart.mock.aria")}>
        {[0, 50, 100].map((tick) => (
          <g key={tick}>
            <line x1={PAD.left} x2={W - PAD.right} y1={y(tick)} y2={y(tick)} stroke="var(--chart-grid)" strokeWidth="1" />
            <text x={PAD.left - 6} y={y(tick) + 3.5} textAnchor="end" fontSize="10" fill="var(--chart-axis)" className="numeral">
              {tick}
            </text>
          </g>
        ))}
        {target != null ? (
          <g>
            <line
              x1={PAD.left}
              x2={W - PAD.right}
              y1={y(target)}
              y2={y(target)}
              stroke="var(--color-ink)"
              strokeWidth="1"
              strokeOpacity="0.5"
              strokeDasharray="3 3"
            />
            {/* Un trait sans nom se lit comme une erreur de tracé. */}
            <text x={W - PAD.right} y={y(target) - 4} textAnchor="end" fontSize="10" fill="var(--color-ink)" fillOpacity="0.6" className="numeral">
              {t("app.chart.mock.target", { percent: target })}
            </text>
          </g>
        ) : null}
        <path d={path} fill="none" stroke="var(--chart-work)" strokeWidth="2" strokeLinejoin="round" strokeLinecap="round" />
        {ordered.map((point, index) => (
          <g key={point.id}>
            <circle cx={x(index)} cy={y(point.score)} r="12" fill="transparent">
              <title>{t("app.chart.mock.point", { score: point.score, day: dateLabel(point.finishedAt), total: point.questionCount })}</title>
            </circle>
            <circle cx={x(index)} cy={y(point.score)} r="4.5" fill="var(--chart-work)" stroke="var(--color-surface)" strokeWidth="2" pointerEvents="none" />
            {(index === 0 || index === ordered.length - 1 || ordered.length <= 4) ? (
              <text x={x(index)} y={H - 6} textAnchor={index === ordered.length - 1 && ordered.length > 1 ? "end" : index === 0 && ordered.length > 1 ? "start" : "middle"} fontSize="10" fill="var(--chart-axis)" className="numeral">
                {dateLabel(point.finishedAt)}
              </text>
            ) : null}
          </g>
        ))}
        <text x={x(ordered.length - 1) + 8} y={y(last.score) + 3.5} fontSize="11" fontWeight="600" fill="var(--color-ink)" className="numeral">
          {last.score} %
        </text>
      </svg>
      <SrTable
        caption={t("app.chart.mock.aria")}
        headers={[t("app.chart.table.day"), t("app.chart.table.score")]}
        rows={ordered.map((point) => [point.finishedAt, `${point.score} % (${point.questionCount})`])}
      />
    </div>
  );
}
