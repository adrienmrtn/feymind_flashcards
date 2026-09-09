"use client";

import { useMemo } from "react";
import Link from "next/link";

import { activeDeadlines, buildQueue, resolveEmoji, type CardState } from "@micabo/core";

import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/ui/card";
import { requestPaywall } from "@/lib/paywall";
import { copyPracticeReview } from "@/lib/i18n/copy";
import { useI18n } from "@/lib/i18n/client";

export interface ReviewSetupCard {
  id: string;
  courseId: string | null;
  state: CardState;
  dueDate: string;
  position: number;
  createdAt: string;
  isSuspended: boolean;
}

export interface ReviewSetupCourse {
  id: string;
  title: string;
  emoji: string | null;
  subject: string | null;
}

export interface ReviewSetupExam {
  date: string;
  isPlanned: boolean;
  courseIds: string[];
}

/**
 * L'écran avant la session : **un chiffre, un bouton.**
 *
 * Il portait un réglage - combien de cartes neuves accepter aujourd'hui - et une phrase qui
 * annonçait parfois « tu as atteint ton rythme, reviens demain ». Les deux sont partis avec
 * le plafond quotidien. Ce qui est dû est servi, et la seule chose à décider ici est de
 * commencer.
 */
export function ReviewSetup({
  courseId,
  cards,
  courses,
  exams,
  isPro,
}: {
  courseId: string | null;
  cards: ReviewSetupCard[];
  courses: ReviewSetupCourse[];
  exams: ReviewSetupExam[];
  isPro: boolean;
}) {
  const { t } = useI18n();
  const now = useMemo(() => new Date(), []);

  const deadlines = useMemo(
    () =>
      activeDeadlines(
        exams.map((exam) => ({
          date: new Date(`${exam.date}T12:00:00`),
          isPlanned: exam.isPlanned,
          courseIds: exam.courseIds,
        })),
        cards.map((card) => ({ id: card.id, courseId: card.courseId, isSuspended: card.isSuspended })),
        now,
      ),
    [cards, exams, now],
  );

  const queue = useMemo(
    () =>
      buildQueue(
        cards.map((card) => ({
          id: card.id,
          state: card.state,
          dueDate: new Date(card.dueDate),
          position: card.position,
          createdAt: new Date(card.createdAt),
          isSuspended: card.isSuspended,
        })),
        { now, deadlines },
      ),
    [cards, deadlines, now],
  );

  const fresh = queue.filter((card) => card.state === "new").length;
  const again = queue.length - fresh;
  const served = queue.length;

  const courseOf = new Map(cards.map((card) => [card.id, card.courseId]));
  const perCourse = courses
    .map((course) => ({
      course,
      count: queue.filter((item) => courseOf.get(item.id) === course.id).length,
    }))
    .filter((entry) => entry.count > 0)
    .sort((left, right) => right.count - left.count);

  const href = courseId != null ? `/app/reviser?cours=${courseId}&go=1` : "/app/reviser?go=1";

  if (served === 0) {
    const empty = cards.length === 0;
    return (
      <EmptyState
        title={t("app.review.empty.title")}
        description={
          empty
            ? t("app.review.empty.importBody")
            : isPro
              ? t("app.review.empty.proAhead")
              : t("app.review.empty.proGate")
        }
        action={
          empty ? (
            <Button render={<Link href={"/app/importer" as never} />}>
              {t("app.import.importCourse")}
            </Button>
          ) : isPro ? (
            <Button render={<Link href={"/app/cours" as never} />}>{t("app.review.seeCourses")}</Button>
          ) : (
            <Button onClick={requestPaywall}>{copyPracticeReview(t)}</Button>
          )
        }
      />
    );
  }

  return (
    <div className="mx-auto w-full max-w-[560px]" data-tour="reviser-panneau">
      <header>
        <h1 className="page-title">{t("nav.review")}</h1>
        <p className="page-lead">
          {courseId ? t("app.review.scope.course") : t("app.review.scope.today")}
        </p>
      </header>

      <section className="panel mt-5 p-6">
        <p className="flex items-baseline gap-2">
          <span className="hero-value">{served}</span>
          <span className="text-[14px] text-ink-secondary">
            {t("app.review.setup.cards", { count: served })}
          </span>
        </p>
        <p className="numeral mt-2 text-[13px] text-ink-tertiary">
          {t("app.review.setup.mix", { due: again, fresh })}
        </p>

        {perCourse.length > 0 ? (
          <ul className="mt-4 flex flex-wrap gap-1.5">
            {perCourse.map(({ course, count }) => (
              <li
                key={course.id}
                className="flex items-center gap-1.5 rounded-full bg-surface-muted py-1 pl-2 pr-2.5 text-[12.5px] text-ink"
              >
                <span aria-hidden className="emoji text-[13px]">
                  {resolveEmoji(course.emoji, course.subject, course.title)}
                </span>
                <span className="max-w-[18ch] truncate">{course.title}</span>
                <span className="numeral text-ink-tertiary">{count}</span>
              </li>
            ))}
          </ul>
        ) : null}

        <div className="mt-6">
          <Button className="h-12 w-full text-[15px]" render={<Link href={href as never} />}>
            {t("app.review.start")}
          </Button>
        </div>
      </section>
    </div>
  );
}
