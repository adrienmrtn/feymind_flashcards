"use client";

import Link from "next/link";

import { useI18n } from "@/lib/i18n/client";

/**
 * **Où en est cette épreuve**, et comment ça bouge.
 *
 * La ligne du plan dit un chiffre ; ici on montre d'où il vient. Trois choses, et pas une de
 * plus : la préparation aujourd'hui contre celle du jour J, la suite des scores de blancs, et
 * l'écart entre les deux mesures.
 *
 * **La suite des scores compte plus que le dernier.** Un blanc à 54 % ne dit presque rien
 * seul ; 54 puis 71 dit que la correction a pris, et 54 puis 52 dit qu'il faut changer de
 * méthode et pas insister. C'est la seule chose du produit qui distingue « je travaille » de
 * « ça marche ».
 */

export interface MockPoint {
  id: string;
  score: number;
  questionCount: number;
  finishedAt: string;
}

export function ExamProgress({
  masteryPercent,
  projectedPercent,
  measured,
  mockScore,
  cardCount,
  daysRemaining,
  mocks,
}: {
  masteryPercent: number;
  projectedPercent: number;
  measured: boolean;
  mockScore: number | null;
  cardCount: number;
  daysRemaining: number;
  mocks: MockPoint[];
}) {
  const { t } = useI18n();
  const trend =
    mocks.length >= 2 ? mocks[0]!.score - mocks[1]!.score : null;

  return (
    <section className="rounded-group border border-border bg-card p-5" data-tour="epreuve-avancee">
      <h2 className="text-[15px] font-semibold text-ink">{t("app.exam.progress.title")}</h2>

      <div className="mt-4 grid gap-5 sm:grid-cols-2">
        <div>
          <p className="text-[12.5px] text-ink-tertiary">
            {measured ? t("app.exam.progress.measured") : t("app.exam.progress.now")}
          </p>
          <p className="numeral mt-1 text-[34px] font-bold leading-none tracking-tight text-ink">
            {measured && mockScore != null ? mockScore : masteryPercent}
            <span className="text-[20px]"> %</span>
          </p>
          <p className="mt-1 text-[12.5px] text-ink-tertiary">
            {t("app.exam.progress.of", { count: cardCount })}
          </p>
        </div>

        <div>
          <p className="text-[12.5px] text-ink-tertiary">{t("app.exam.progress.projected")}</p>
          <p className="numeral mt-1 text-[34px] font-bold leading-none tracking-tight text-accent">
            {projectedPercent}
            <span className="text-[20px]"> %</span>
          </p>
          <p className="mt-1 text-[12.5px] text-ink-tertiary">
            {t("app.exam.progress.onDay", { count: Math.max(0, daysRemaining) })}
          </p>
        </div>
      </div>

      <div
        className="mt-5 h-2 w-full overflow-hidden rounded-pill bg-surface-sunken"
        role="img"
        aria-label={t("app.plan.exams.readiness", {
          now: masteryPercent,
          projected: projectedPercent,
        })}
      >
        <span
          className="block h-full rounded-pill bg-accent"
          style={{ width: `${Math.max(2, masteryPercent)}%` }}
        />
      </div>

      {mocks.length > 0 ? (
        <div className="mt-6">
          <div className="flex flex-wrap items-baseline justify-between gap-3">
            <p className="text-[14px] font-semibold text-ink">{t("app.exam.progress.mocks")}</p>
            {trend != null ? (
              <p
                className={`numeral text-[13px] font-semibold ${
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

          <ul className="mt-3 space-y-1.5">
            {mocks.map((mock) => (
              <li key={mock.id} className="flex items-center gap-3">
                <span className="numeral w-20 shrink-0 text-[12.5px] text-ink-tertiary">
                  {mock.finishedAt}
                </span>
                <span
                  aria-hidden
                  className="h-2 min-w-0 flex-1 overflow-hidden rounded-pill bg-surface-sunken"
                >
                  <span
                    className={`block h-full rounded-pill ${
                      mock.score >= 75
                        ? "bg-positive"
                        : mock.score >= 50
                          ? "bg-caution"
                          : "bg-negative"
                    }`}
                    style={{ width: `${Math.max(2, mock.score)}%` }}
                  />
                </span>
                <span className="numeral w-20 shrink-0 text-right text-[12.5px] text-ink">
                  {t("app.mock.scoreLine", {
                    score: mock.score,
                    total: mock.questionCount,
                  })}
                </span>
              </li>
            ))}
          </ul>

          {measured && mockScore != null ? (
            <p className="mt-3 text-[12.5px] leading-relaxed text-ink-secondary">
              {masteryPercent - mockScore >= 15
                ? t("app.exam.progress.gapWide", { mastery: masteryPercent, score: mockScore })
                : t("app.exam.progress.gapClose")}
            </p>
          ) : null}
        </div>
      ) : (
        <p className="mt-5 text-[13.5px] leading-relaxed text-ink-secondary">
          {t("app.exam.progress.noMock")}
        </p>
      )}

      <p className="mt-4 text-[13px]">
        <Link href={"/app/progres" as never} className="underline-draw font-medium text-ink-secondary">
          {t("app.exam.progress.seeAll")}
        </Link>
      </p>
    </section>
  );
}
