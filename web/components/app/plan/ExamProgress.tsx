"use client";

import Link from "next/link";

import { MockTrend, type MockPoint } from "@/components/app/charts/MockTrend";
import { ReadinessBar } from "@/components/app/charts/ReadinessBar";
import { useI18n } from "@/lib/i18n/client";

export type { MockPoint } from "@/components/app/charts/MockTrend";

/**
 * **Où en est cette épreuve**, et comment ça bouge.
 *
 * Une barre pour la préparation (aujourd'hui, le jour J, l'objectif), une courbe pour les
 * blancs. La suite des scores compte plus que le dernier : 54 puis 71 dit que la correction
 * a pris, 54 puis 52 dit qu'il faut changer de méthode et pas insister.
 */
export function ExamProgress({
  masteryPercent,
  measured,
  mockScore,
  cardCount,
  daysRemaining,
  targetScore,
  mocks,
}: {
  masteryPercent: number;
  measured: boolean;
  mockScore: number | null;
  cardCount: number;
  daysRemaining: number;
  targetScore: number | null;
  mocks: MockPoint[];
}) {
  const { t } = useI18n();
  const ordered = [...mocks].sort((left, right) => (left.finishedAt < right.finishedAt ? 1 : -1));
  const trend = ordered.length >= 2 ? ordered[0]!.score - ordered[1]!.score : null;

  return (
    <section className="panel p-5" data-tour="epreuve-avancee">
      <div className="flex flex-wrap items-baseline justify-between gap-3">
        <h2 className="section-title">{t("app.exam.progress.title")}</h2>
        <p className="numeral text-[12.5px] text-ink-tertiary">
          {t("app.exam.progress.of", { count: cardCount })}
          {daysRemaining >= 0 ? ` · ${t("app.exam.progress.onDay", { count: daysRemaining })}` : ""}
        </p>
      </div>

      <div className="mt-4">
        <ReadinessBar
          now={measured && mockScore != null ? mockScore : masteryPercent}
          target={targetScore}
          measured={measured}
        />
      </div>

      <div className="mt-6 border-t border-hairline pt-5">
        <div className="flex flex-wrap items-baseline justify-between gap-3">
          <h3 className="section-title">{t("app.exam.progress.mocks")}</h3>
          {trend != null ? (
            <p
              className={`numeral text-[12.5px] font-semibold ${
                trend > 0 ? "text-positive" : trend < 0 ? "text-negative" : "text-ink-tertiary"
              }`}
            >
              {trend > 0
                ? t("app.exam.progress.up", { points: trend })
                : trend < 0
                  ? t("app.exam.progress.down", { points: Math.abs(trend) })
                  : t("app.exam.progress.flat")}
            </p>
          ) : null}
        </div>

        {mocks.length > 0 ? (
          <>
            <div className="mt-3">
              <MockTrend points={mocks} target={targetScore} />
            </div>
            {measured && mockScore != null ? (
              <p className="mt-3 text-[13px] leading-relaxed text-ink-secondary">
                {masteryPercent - mockScore >= 15
                  ? t("app.exam.progress.gapWide", { mastery: masteryPercent, score: mockScore })
                  : t("app.exam.progress.gapClose")}
              </p>
            ) : null}
          </>
        ) : (
          <p className="mt-2 text-[13px] leading-relaxed text-ink-secondary">
            {t("app.exam.progress.noMock")}
          </p>
        )}
      </div>

      <p className="mt-4 text-[12.5px]">
        <Link href={"/app/progres" as never} className="underline-draw font-medium text-ink-secondary">
          {t("app.exam.progress.seeAll")}
        </Link>
      </p>
    </section>
  );
}
