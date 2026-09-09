"use client";

import { useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";

import { courseAccent } from "@micabo/core";

import { Button } from "@/components/ui/button";
import { startMockSession } from "@/lib/actions/mocks";
import { useI18n } from "@/lib/i18n/client";
import type { PlanTodayBlock } from "@/lib/term-plan";

/**
 * Le travail du jour, et le bouton qui le lance.
 *
 * C'est le premier panneau de l'app, et il ne fait qu'une chose : dire ce qu'il y a à faire
 * et permettre de le faire. Les blocs viennent du plan quand il y en a un ; sinon ce sont les
 * cartes dues, et le bouton dit la même chose dans les deux cas : réviser.
 */
export function TodayPanel({
  blocks,
  minutes,
  cards,
  dueCards,
  hasCards,
}: {
  blocks: PlanTodayBlock[];
  minutes: number;
  cards: number;
  /** Les cartes dues aujourd'hui hors plan, quand aucune épreuve ne pilote. */
  dueCards: number;
  hasCards: boolean;
}) {
  const { t } = useI18n();
  const planned = blocks.length > 0;
  const total = planned ? cards : dueCards;
  const reviewBlocks = blocks.filter((block) => block.kind === "review");
  const mockBlocks = blocks.filter((block) => block.kind === "mock");

  if (total === 0 && mockBlocks.length === 0) {
    return (
      <section className="panel p-6" data-tour="aujourdhui">
        <p className="section-title">{t("app.today.done")}</p>
        <p className="section-lead max-w-[52ch]">
          {hasCards ? t("app.today.doneBody") : t("app.today.doneEmpty")}
        </p>
        <div className="mt-4 flex flex-wrap gap-2">
          {hasCards ? (
            <Button variant="outline" size="sm" render={<Link href={"/app/cours" as never} />}>
              {t("app.review.seeCourses")}
            </Button>
          ) : (
            <Button size="sm" render={<Link href={"/app/importer" as never} />}>
              {t("app.import.importCourse")}
            </Button>
          )}
        </div>
      </section>
    );
  }

  return (
    <section className="panel overflow-hidden" data-tour="aujourdhui">
      <div className="flex flex-wrap items-end justify-between gap-4 p-6 pb-5">
        <div>
          <p className="stat-label">{t("nav.today")}</p>
          <p className="mt-1.5 flex items-baseline gap-2">
            <span className="hero-value">{total}</span>
            <span className="text-[14px] text-ink-secondary">
              {planned
                ? t("app.today.cardsMinutes", { count: total, minutes })
                : t("app.today.cardsDue", { count: total })}
            </span>
          </p>
        </div>
        {total > 0 ? (
          <Button className="h-11 px-5" render={<Link href={"/app/reviser?go=1" as never} />}>
            {planned ? t("app.today.start", { minutes }) : t("app.today.startCards", { count: total })}
          </Button>
        ) : null}
      </div>

      {planned ? (
        <ul className="divide-y divide-hairline border-t border-hairline">
          {reviewBlocks.map((block) => (
            <li key={`${block.examId}:${block.courseId ?? "sans"}`} className="flex items-center gap-3 px-6 py-3">
              <span
                aria-hidden
                className="flex size-9 shrink-0 items-center justify-center rounded-[10px] text-[17px]"
                style={{ backgroundColor: `${courseAccent(block.courseId ?? block.examId)}1a` }}
              >
                {block.emoji}
              </span>
              <span className="min-w-0 flex-1">
                <span className="block truncate text-[14px] font-medium text-ink">{block.courseTitle}</span>
                <span className="block truncate text-[12.5px] text-ink-tertiary">
                  {t("app.today.forExam", { exam: block.examName })}
                </span>
              </span>
              <span className="numeral shrink-0 text-[12.5px] text-ink-secondary">
                {t("app.today.block", { cards: block.cards, minutes: block.minutes })}
              </span>
            </li>
          ))}
          {mockBlocks.map((block) => (
            <li key={`mock:${block.examId}`} className="flex items-center gap-3 px-6 py-3">
              <span
                aria-hidden
                className="flex size-9 shrink-0 items-center justify-center rounded-[10px] bg-caution-soft text-[17px]"
              >
                ⏱
              </span>
              <span className="min-w-0 flex-1">
                <span className="block truncate text-[14px] font-medium text-ink">
                  {t("app.today.mockTitle", { exam: block.examName })}
                </span>
                <span className="numeral block truncate text-[12.5px] text-ink-tertiary">
                  {t("app.today.mock", { questions: block.cards, minutes: block.minutes })}
                </span>
              </span>
              <StartMock examId={block.examId} />
            </li>
          ))}
        </ul>
      ) : null}
    </section>
  );
}

function StartMock({ examId }: { examId: string }) {
  const { t } = useI18n();
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  return (
    <Button
      size="sm"
      variant="outline"
      disabled={pending}
      onClick={() =>
        startTransition(async () => {
          const result = await startMockSession(examId);
          if (result.status === "ok" && result.sessionId) {
            router.push(`/app/plan/blanc/${result.sessionId}` as never);
          }
        })
      }
    >
      {pending ? t("app.exams.wait") : t("app.mock.start")}
    </Button>
  );
}
