"use client";

import { useMemo, useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";

import {
  adherenceLevel,
  courseAccent,
  examCountdownLabel,
  examUrgency,
  type Adherence,
  type LoadBar,
  type TermLever,
  type TermVerdict,
  type Throughput,
} from "@micabo/core";

import { Button } from "@/components/ui/button";
import { ExamCalendar, isoDay, type CalendarExam } from "@/components/app/exams/ExamCalendar";
import { startMockSession } from "@/lib/actions/mocks";
import { useI18n } from "@/lib/i18n/client";

import { TermStrip, type StripExam } from "./TermStrip";
import { Verdict } from "./Verdict";

/**
 * Le Plan : **la frise, le verdict, le travail du jour, les épreuves.**
 *
 * L'ancien écran s'ouvrait sur un calendrier mensuel, c'est-à-dire sur un sélecteur de date.
 * Il répondait à « quand est mon examen », que l'étudiant sait déjà, et pas à « est-ce que je
 * vais y arriver », qui est la seule question qui l'amène ici. L'ordre est donc inversé : le
 * calendrier existe encore, replié, pour poser une date.
 *
 * Le travail du jour vient du plan et non de la file de révision : ce sont les mêmes cartes,
 * mais l'ordre est celui de la période, pas celui d'aujourd'hui pris isolément.
 */

export interface PlanExam {
  id: string;
  name: string;
  examDate: string;
  daysRemaining: number;
  courseIds: string[];
  masteryPercent: number;
  projectedPercent: number;
  /** Vrai quand la préparation vient d'un blanc passé et non d'une projection. */
  measured: boolean;
  mockScore: number | null;
  cardCount: number;
  isPlanned: boolean;
}

export interface PlanTodayBlock {
  kind: "review" | "mock";
  courseId: string | null;
  courseTitle: string;
  emoji: string;
  examId: string;
  examName: string;
  cards: number;
  minutes: number;
}

export function PlanWorkspace({
  bars,
  verdict,
  levers,
  exams,
  todayBlocks,
  todayMinutes,
  todayCards,
  courses,
  weeklyMinutes,
  adherence,
  throughput,
}: {
  bars: LoadBar[];
  verdict: TermVerdict;
  levers: TermLever[];
  exams: PlanExam[];
  todayBlocks: PlanTodayBlock[];
  todayMinutes: number;
  todayCards: number;
  courses: { id: string; title: string }[];
  weeklyMinutes: number;
  adherence: Adherence;
  throughput: Throughput;
}) {
  const { t } = useI18n();
  const router = useRouter();
  const [showMonth, setShowMonth] = useState(false);
  const [month, setMonth] = useState(() => {
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), 1);
  });

  const upcoming = exams.filter((exam) => exam.daysRemaining >= 0);
  const past = exams.filter((exam) => exam.daysRemaining < 0);

  const stripExams: StripExam[] = useMemo(
    () =>
      upcoming.map((exam) => ({
        id: exam.id,
        name: exam.name,
        offset: exam.daysRemaining,
      })),
    [upcoming],
  );

  const calendarExams: CalendarExam[] = exams.map((exam) => ({
    id: exam.id,
    name: exam.name,
    examDate: exam.examDate,
    isPast: exam.daysRemaining < 0,
  }));

  if (upcoming.length === 0) {
    return <EmptyPlan hasCourses={courses.length > 0} />;
  }

  return (
    <>
      <section className="rounded-group border border-border bg-card p-5" data-tour="plan-frise">
        <div className="mb-4 flex flex-wrap items-baseline justify-between gap-3">
          <h2 className="text-[15px] font-semibold text-ink">{t("app.plan.strip.title")}</h2>
          <Button
            variant="link"
            size="sm"
            className="h-auto px-0"
            render={<Link href={"/app/plan/semaines" as never} />}
          >
            {t("app.plan.weekly.open", { minutes: weeklyMinutes })}
          </Button>
        </div>
        <TermStrip bars={bars} exams={stripExams} />
      </section>

      <Verdict verdict={verdict} levers={levers} exams={upcoming} />

      <TodayWork blocks={todayBlocks} minutes={todayMinutes} cards={todayCards} />

      <Calibration adherence={adherence} throughput={throughput} />

      <section>
        <div className="mb-3 flex flex-wrap items-baseline justify-between gap-3">
          <h2 className="text-[15px] font-semibold text-ink">{t("app.plan.exams.title")}</h2>
          <Button
            size="sm"
            data-tour="examens-ajouter"
            render={<Link href={"/app/plan/nouveau" as never} />}
          >
            {t("app.newPlan.add")}
          </Button>
        </div>
        <ul className="space-y-2">
          {upcoming.map((exam) => (
            <li key={exam.id}>
              <ExamRow exam={exam} />
            </li>
          ))}
        </ul>
      </section>

      <section>
        <button
          type="button"
          onClick={() => setShowMonth((open) => !open)}
          className="pressable text-[13.5px] font-medium text-ink-secondary underline-draw"
          aria-expanded={showMonth}
        >
          {showMonth ? t("app.plan.month.hide") : t("app.plan.month.show")}
        </button>

        {showMonth ? (
          <div className="mt-4" data-tour="examens-calendrier">
            <ExamCalendar
              month={month}
              selected={null}
              exams={calendarExams}
              onMonth={setMonth}
              onSelect={(day) => {
                const existing = exams.find((exam) => exam.examDate === isoDay(day));
                if (existing) router.push(`/app/plan/${existing.id}` as never);
              }}
            />
            <p className="mt-3 text-center text-[12.5px] text-ink-secondary">
              {t("app.plan.month.hint")}
            </p>
          </div>
        ) : null}
      </section>

      {past.length > 0 ? (
        <section>
          <p className="mb-3 text-[13px] font-medium text-muted-foreground">
            {t("app.exams.past")}
          </p>
          <ul className="divide-y divide-hairline overflow-hidden rounded-2xl border border-border bg-card">
            {past.map((exam) => (
              <li key={exam.id}>
                <Link
                  href={`/app/plan/${exam.id}` as never}
                  className="hover-row flex w-full items-baseline justify-between gap-4 px-5 py-3.5 text-left"
                >
                  <span className="text-[14.5px] text-ink-secondary">{exam.name}</span>
                  <span className="numeral shrink-0 text-[13px] text-ink-tertiary">
                    {exam.examDate}
                  </span>
                </Link>
              </li>
            ))}
          </ul>
        </section>
      ) : null}

    </>
  );
}

function TodayWork({
  blocks,
  minutes,
  cards,
}: {
  blocks: PlanTodayBlock[];
  minutes: number;
  cards: number;
}) {
  const { t } = useI18n();

  return (
    <section className="rounded-group border border-border bg-card p-5" data-tour="plan-aujourdhui">
      <div className="mb-3 flex flex-wrap items-baseline justify-between gap-3">
        <h2 className="text-[15px] font-semibold text-ink">{t("app.plan.today.title")}</h2>
        {blocks.length > 0 ? (
          <Button size="sm" render={<Link href={"/app/reviser?go=1" as never} />}>
            {t("app.plan.today.start", { minutes })}
          </Button>
        ) : null}
      </div>

      {blocks.length === 0 ? (
        <p className="text-[14px] text-ink-secondary">{t("app.plan.today.nothing")}</p>
      ) : (
        <ul className="divide-y divide-hairline">
          {blocks.map((block) => (
            <li
              key={`${block.kind}:${block.examId}:${block.courseId ?? "sans"}`}
              className="flex items-center gap-3 py-3 first:pt-0 last:pb-0"
            >
              <span
                aria-hidden
                className="flex h-10 w-10 shrink-0 items-center justify-center rounded-tile text-[18px]"
                style={{
                  backgroundColor:
                    block.kind === "mock"
                      ? "var(--color-caution-soft)"
                      : `${courseAccent(block.courseId ?? block.examId)}1f`,
                }}
              >
                {block.emoji}
              </span>
              <span className="min-w-0 flex-1">
                <span className="block truncate text-[15px] font-medium text-ink">
                  {block.courseTitle}
                </span>
                <span className="numeral mt-0.5 block truncate text-[12.5px] text-ink-tertiary">
                  {block.kind === "mock"
                    ? t("app.mock.blockLine", {
                        exam: block.examName,
                        questions: block.cards,
                        minutes: block.minutes,
                      })
                    : t("app.plan.today.forExam", {
                        exam: block.examName,
                        cards: block.cards,
                        minutes: block.minutes,
                      })}
                </span>
              </span>
              {block.kind === "mock" ? <StartMock examId={block.examId} /> : null}
            </li>
          ))}
        </ul>
      )}

      {cards > 0 ? (
        <p className="mt-3 text-[12.5px] text-ink-tertiary">
          {t("app.plan.today.total", { cards, minutes })}
        </p>
      ) : null}
    </section>
  );
}

/**
 * Le débit et l'observance, dits une fois.
 *
 * Le bloc ne s'affiche que **quand il y a quelque chose à dire** : tant que rien n'est mesuré,
 * le plan tourne sur ses valeurs par défaut et annoncer « débit standard » n'apprendrait rien
 * à personne. De même quand tout va bien : on ne félicite pas quelqu'un de suivre son plan.
 */
function Calibration({
  adherence,
  throughput,
}: {
  adherence: Adherence;
  throughput: Throughput;
}) {
  const { t } = useI18n();
  const level = adherenceLevel(adherence);
  const drifted = throughput.measured && Math.abs(throughput.driftPercent) >= 15;

  if (level === "steady" && !drifted) return null;

  return (
    <section className="rounded-group border border-border bg-surface-muted p-5">
      <h2 className="text-[15px] font-semibold text-ink">{t("app.plan.calibration.title")}</h2>
      <ul className="mt-2 space-y-1.5 text-[13.5px] leading-relaxed text-ink-secondary">
        {drifted ? (
          <li>
            {throughput.driftPercent < 0
              ? t("app.plan.calibration.slower", {
                  rate: throughput.cardsPerMinute,
                  percent: Math.abs(throughput.driftPercent),
                })
              : t("app.plan.calibration.faster", {
                  rate: throughput.cardsPerMinute,
                  percent: throughput.driftPercent,
                })}
          </li>
        ) : null}
        {level !== "steady" ? (
          <li>
            {t(
              level === "behind"
                ? "app.plan.calibration.behind"
                : "app.plan.calibration.slipping",
              { percent: Math.round(adherence.ratio * 100), days: adherence.missedDays },
            )}
          </li>
        ) : null}
      </ul>
    </section>
  );
}

/** Ouvrir un blanc : l'action pose le tirage, puis la page de passation le sert. */
function StartMock({ examId }: { examId: string }) {
  const { t } = useI18n();
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  return (
    <Button
      size="sm"
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

function ExamRow({ exam }: { exam: PlanExam }) {
  const { t } = useI18n();
  const urgency = examUrgency(exam.daysRemaining);
  const tone =
    urgency === "critical"
      ? "bg-negative-soft text-negative"
      : urgency === "soon"
        ? "bg-caution-soft text-caution"
        : urgency === "upcoming"
          ? "bg-info-soft text-info"
          : "bg-surface-muted text-ink-secondary";

  return (
    <Link
      href={`/app/plan/${exam.id}` as never}
      className="hover-tile flex w-full min-w-0 items-center justify-between gap-4 rounded-group border border-border bg-card px-5 py-4"
    >
      <span className="min-w-0 flex-1">
        <span className="block truncate text-[15.5px] font-semibold text-ink">{exam.name}</span>
        <span className="mt-1.5 flex items-center gap-2">
          <span
            aria-hidden
            className="h-1.5 w-24 shrink-0 overflow-hidden rounded-pill bg-surface-sunken"
          >
            <span
              className="block h-full rounded-pill bg-accent"
              style={{ width: `${Math.max(2, exam.masteryPercent)}%` }}
            />
          </span>
          <span className="numeral truncate text-[12.5px] text-ink-secondary">
            {exam.measured && exam.mockScore != null
              ? t("app.plan.exams.measured", {
                  score: exam.mockScore,
                  projected: exam.projectedPercent,
                })
              : t("app.plan.exams.readiness", {
                  now: exam.masteryPercent,
                  projected: exam.projectedPercent,
                })}
          </span>
        </span>
      </span>
      <span className={`numeral shrink-0 rounded-pill px-2.5 py-1 text-[12px] font-semibold ${tone}`}>
        {examCountdownLabel(exam.daysRemaining)}
      </span>
    </Link>
  );
}

/**
 * L'écran sans plan : **la seule chose à faire y est de s'en créer un.**
 *
 * Il n'envoie plus vers l'import quand il n'y a pas de cours : le parcours de création
 * commence justement par le matériel, donc y aller sans rien est le chemin normal et pas un
 * cas dégradé.
 */
function EmptyPlan({ hasCourses }: { hasCourses: boolean }) {
  const { t } = useI18n();

  return (
    <section className="rounded-group border border-border bg-card p-8 text-center">
      <p className="text-[19px] font-semibold text-ink">{t("app.plan.empty.title")}</p>
      <p className="mx-auto mt-2 max-w-[48ch] text-[14.5px] leading-relaxed text-ink-secondary">
        {hasCourses ? t("app.plan.empty.body") : t("app.plan.empty.bodyFresh")}
      </p>
      <div className="mt-6">
        <Button className="h-12 px-6" render={<Link href={"/app/plan/nouveau" as never} />}>
          {t("app.newPlan.add")}
        </Button>
      </div>
      <p className="mt-3 text-[12.5px] text-ink-tertiary">{t("app.newPlan.emptyHint")}</p>
    </section>
  );
}
