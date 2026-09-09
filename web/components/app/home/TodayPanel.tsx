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
 * et permettre de le faire.
 *
 * **Le nombre affiché est celui que le bouton sert.** Ça paraît évident ; ça ne l'était pas.
 * Le compte venait des blocs du plan - ce que la période prévoit pour aujourd'hui - tandis que
 * le bouton ouvrait la file, qui sert tout ce qui est dû. Les deux ne disaient pas la même
 * chose : l'écran annonçait neuf cartes, la session en servait cent trente, et finir « les
 * neuf » laissait un compte qui n'avait pas bougé. Un chiffre qu'on ne peut pas ramener à zéro
 * en faisant ce qu'il demande est pire qu'un chiffre absent.
 *
 * Les blocs restent dessous : ils disent **d'où vient** ce travail, cours par cours et épreuve
 * par épreuve. Ce sont deux questions différentes, et une seule des deux commande le bouton.
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
  /** Ce que le plan prévoit pour aujourd'hui. Sert aux blocs, pas au grand chiffre. */
  cards: number;
  /** Les cartes réellement dues : c'est ce que « Réviser » sert, donc c'est ce qui s'affiche. */
  dueCards: number;
  hasCards: boolean;
}) {
  const { t } = useI18n();
  const planned = blocks.length > 0;
  const total = dueCards;
  /**
   * Les minutes ne s'affichent que si elles parlent du même travail.
   *
   * Elles viennent du plan, qui compte ce qu'il a posé pour aujourd'hui. Quand la file en
   * contient plus - du retard, un cours sans épreuve - annoncer « 13 min » devant 92 cartes
   * promet un quart d'heure pour une heure de travail.
   */
  const sameWork = planned && cards === total;
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
              {sameWork
                ? t("app.today.cardsMinutes", { count: total, minutes })
                : t("app.today.cardsDue", { count: total })}
            </span>
          </p>
        </div>
        {total > 0 ? (
          <Button className="h-11 px-5" render={<Link href={"/app/reviser?go=1" as never} />}>
            {sameWork ? t("app.today.start", { minutes }) : t("app.today.startCards", { count: total })}
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
