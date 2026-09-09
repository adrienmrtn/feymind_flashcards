"use client";

import { useMemo, useState } from "react";
import Link from "next/link";

import { activeDeadlines, buildQueue, resolveEmoji, type CardState } from "@micabo/core";

import { CountStepper } from "@/components/app/CountStepper";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/ui/card";
import { requestPaywall } from "@/lib/paywall";
import { copyHeldBackNew, copyPracticeReview } from "@/lib/i18n/copy";
import { useI18n } from "@/lib/i18n/client";
import type { Translator } from "@/lib/i18n/copy";

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
 * Il tenait en quatre blocs séparés (deux compteurs, une liste, un bouton), qu'on lisait
 * comme un formulaire. C'est une seule carte : combien de cartes, d'où elles viennent, et
 * le bouton pour y aller. Le réglage des cartes neuves reste, replié dans la carte, parce
 * que c'est le seul choix qu'on fait ici.
 */
export function ReviewSetup({
  courseId,
  cards,
  courses,
  exams,
  remaining,
  isPro,
}: {
  courseId: string | null;
  cards: ReviewSetupCard[];
  courses: ReviewSetupCourse[];
  exams: ReviewSetupExam[];
  rhythmNew: number;
  introducedToday: number;
  remaining: number;
  isPro: boolean;
}) {
  const { t } = useI18n();
  const now = useMemo(() => new Date(), []);
  const dueNew = cards.filter(
    (card) => !card.isSuspended && card.state === "new" && new Date(card.dueDate) <= now,
  ).length;
  const [freshCap, setFreshCap] = useState(() => Math.min(remaining, dueNew));

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
        {
          now,
          limits: { newPerSession: freshCap, reviewsPerSession: Number.MAX_SAFE_INTEGER },
          deadlines,
        },
      ),
    [cards, deadlines, freshCap, now],
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
    .filter((entry) => entry.count > 0);

  const href =
    courseId != null
      ? `/app/reviser?cours=${courseId}&go=1&neuves=${freshCap}`
      : `/app/reviser?go=1&neuves=${freshCap}`;

  if (queue.length === 0 && dueNew === 0) {
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
            <Button render={<Link href={"/app/importer" as never} />}>{t("app.import.importCourse")}</Button>
          ) : isPro ? (
            <Button render={<Link href={"/app/cours" as never} />}>{t("app.review.seeCourses")}</Button>
          ) : (
            <Button onClick={requestPaywall}>{copyPracticeReview(t)}</Button>
          )
        }
      />
    );
  }

  const leftoverOnly = served === 0 && dueNew > 0;

  return (
    <div className="mx-auto w-full max-w-[560px]" data-tour="reviser-panneau">
      <header>
        <h1 className="page-title">{t("nav.review")}</h1>
        <p className="page-lead">
          {leftoverOnly
            ? copyHeldBackNew(t, dueNew)
            : courseId
              ? t("app.review.scope.course")
              : t("app.review.scope.today")}
        </p>
      </header>

      <section className="panel mt-5 overflow-hidden">
        <div className="p-6">
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
            {served > 0 ? (
              <Button className="h-12 w-full text-[15px]" render={<Link href={href as never} />}>
                {leftoverOnly ? t("app.review.startFresh", { count: fresh }) : t("app.review.start")}
              </Button>
            ) : (
              <p className="text-[13.5px] text-ink-secondary">
                {t("app.review.paceReached")}{" "}
                <Link href={"/app/reglages" as never} className="underline-draw font-medium text-ink">
                  {t("app.home.empty.changePace")}
                </Link>
              </p>
            )}
          </div>
        </div>

        {dueNew > 0 ? (
          <NewCardsControl
            t={t}
            value={Math.min(freshCap, dueNew)}
            max={dueNew}
            planned={remaining}
            onChange={setFreshCap}
          />
        ) : null}
      </section>
    </div>
  );
}

function NewCardsControl({
  t,
  value,
  max,
  planned,
  onChange,
}: {
  t: Translator;
  value: number;
  max: number;
  planned: number;
  onChange: (next: number) => void;
}) {
  const relation = value === planned ? "at" : value > planned ? "above" : "below";
  const info =
    relation === "at"
      ? t("app.review.newCards.atPace")
      : relation === "above"
        ? t("app.review.newCards.above")
        : t("app.review.newCards.below");
  const tone = relation === "at" ? "info" : relation === "above" ? "caution" : "ink";

  return (
    <div className="flex flex-wrap items-center justify-between gap-3 border-t border-hairline bg-surface-muted/50 px-6 py-4">
      <div>
        <p className="text-[13.5px] font-medium text-ink">{t("app.review.setup.newTitle")}</p>
        <p className="mt-0.5 text-[12px] text-ink-tertiary">{t("app.review.setup.newHint", { max })}</p>
      </div>
      <CountStepper
        value={value}
        min={0}
        max={max}
        onChange={onChange}
        minusLabel={t("app.review.newCards.minusAria")}
        plusLabel={t("app.review.newCards.plusAria")}
        tone={tone}
        info={info}
      />
    </div>
  );
}
