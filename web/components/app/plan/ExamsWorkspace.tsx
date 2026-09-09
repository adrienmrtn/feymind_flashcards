"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";

import {
  adherenceLevel,
  examCountdownLabel,
  examUrgency,
  type Adherence,
  type LoadBar,
  type TermLever,
  type TermVerdict,
  type Throughput,
} from "@micabo/core";

import { ExamTimeline } from "@/components/app/charts/ExamTimeline";
import { WeeklyLoad } from "@/components/app/charts/WeeklyLoad";
import { ExamCalendar, isoDay, type CalendarExam } from "@/components/app/exams/ExamCalendar";
import { Button } from "@/components/ui/button";
import { useI18n } from "@/lib/i18n/client";
import type { PlanExam } from "@/lib/term-plan";

import { Verdict } from "./Verdict";

/**
 * Le hub des examens : **lesquelles, quand, et est-ce que ça tient.**
 *
 * D'abord la frise (une ligne par épreuve, une échelle de temps commune), puis la charge
 * semaine par semaine contre le temps donné, puis les épreuves une à une. Le verdict n'est
 * un bloc à part que quand il a quelque chose à demander ; sinon il tient en une ligne sous
 * la charge.
 */
export function ExamsWorkspace({
  bars,
  verdict,
  levers,
  exams,
  weeklyMinutes,
  adherence,
  throughput,
  hasCourses,
}: {
  bars: LoadBar[];
  verdict: TermVerdict;
  levers: TermLever[];
  exams: PlanExam[];
  weeklyMinutes: number;
  adherence: Adherence;
  throughput: Throughput;
  hasCourses: boolean;
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
  const names = new Map(exams.map((exam) => [exam.id, exam.name]));

  if (upcoming.length === 0) {
    return (
      <>
        <EmptyPlan hasCourses={hasCourses} />
        {past.length > 0 ? <PastExams exams={past} /> : null}
      </>
    );
  }

  const calendarExams: CalendarExam[] = exams.map((exam) => ({
    id: exam.id,
    name: exam.name,
    examDate: exam.examDate,
    isPast: exam.daysRemaining < 0,
  }));

  return (
    <>
      <section className="panel p-5" data-tour="examens-frise">
        <div className="mb-4 flex flex-wrap items-baseline justify-between gap-3">
          <h2 className="section-title">{t("app.exams.hub.timeline")}</h2>
          <button
            type="button"
            onClick={() => setShowMonth((open) => !open)}
            className="pressable underline-draw text-[12.5px] font-medium text-ink-secondary"
            aria-expanded={showMonth}
          >
            {showMonth ? t("app.plan.month.hide") : t("app.plan.month.show")}
          </button>
        </div>
        <ExamTimeline
          exams={upcoming.map((exam) => ({
            id: exam.id,
            name: exam.name,
            daysRemaining: exam.daysRemaining,
            readiness: exam.masteryPercent,
          }))}
        />
        {showMonth ? (
          <div className="mt-5 border-t border-hairline pt-5" data-tour="examens-calendrier">
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
            <p className="mt-3 text-center text-[12px] text-ink-tertiary">{t("app.plan.month.hint")}</p>
          </div>
        ) : null}
      </section>

      <section className="panel p-5" data-tour="examens-charge">
        <div className="mb-4 flex flex-wrap items-baseline justify-between gap-3">
          <div>
            <h2 className="section-title">{t("app.exams.hub.load")}</h2>
            {verdict.level !== "short" ? <p className="section-lead">{verdictLine(verdict, t)}</p> : null}
          </div>
          <Link href={"/app/plan/semaines" as never} className="underline-draw text-[12.5px] font-medium text-ink-secondary">
            {t("app.plan.weekly.open", { minutes: weeklyMinutes })}
          </Link>
        </div>
        <WeeklyLoad bars={bars} examNames={names} />
      </section>

      {verdict.level === "short" ? <Verdict verdict={verdict} levers={levers} exams={upcoming} /> : null}

      <Calibration adherence={adherence} throughput={throughput} />

      <section>
        <div className="mb-3 flex flex-wrap items-baseline justify-between gap-3">
          <h2 className="section-title">{t("app.plan.exams.title")}</h2>
        </div>
        <ul className="panel divide-y divide-hairline overflow-hidden">
          {upcoming.map((exam) => (
            <li key={exam.id}>
              <ExamRow exam={exam} />
            </li>
          ))}
        </ul>
      </section>

      {past.length > 0 ? <PastExams exams={past} /> : null}
    </>
  );
}

function verdictLine(verdict: TermVerdict, t: (key: string, values?: Record<string, string | number>) => string): string {
  if (verdict.level === "short") return t("app.plan.verdict.short", { minutes: verdict.deficitMinutes });
  if (verdict.level === "tight") return t("app.plan.verdict.tight", { minutes: verdict.averageMinutes });
  return t("app.plan.verdict.clear", { minutes: verdict.averageMinutes });
}

function ExamRow({ exam }: { exam: PlanExam }) {
  const { t } = useI18n();
  const urgency = examUrgency(exam.daysRemaining);
  const tone =
    urgency === "critical"
      ? "bg-negative-soft text-negative"
      : urgency === "soon"
        ? "bg-caution-soft text-caution"
        : "bg-surface-muted text-ink-secondary";

  return (
    <Link
      href={`/app/plan/${exam.id}` as never}
      className="hover-row flex w-full min-w-0 items-center justify-between gap-4 px-5 py-3.5"
    >
      <span className="min-w-0 flex-1">
        <span className="block truncate text-[14px] font-medium text-ink">{exam.name}</span>
        <span className="numeral mt-0.5 block truncate text-[12.5px] text-ink-tertiary">
          {exam.measured && exam.mockScore != null
            ? t("app.plan.exams.measured", { score: exam.mockScore, projected: exam.projectedPercent })
            : t("app.plan.exams.readiness", { now: exam.masteryPercent, projected: exam.projectedPercent })}
        </span>
      </span>
      <span className={`numeral shrink-0 rounded-full px-2.5 py-1 text-[12px] font-semibold ${tone}`}>
        {examCountdownLabel(exam.daysRemaining)}
      </span>
    </Link>
  );
}

function PastExams({ exams }: { exams: PlanExam[] }) {
  const { t } = useI18n();
  return (
    <section>
      <p className="mb-3 text-[12.5px] font-medium text-ink-tertiary">{t("app.exams.past")}</p>
      <ul className="panel divide-y divide-hairline overflow-hidden">
        {exams.map((exam) => (
          <li key={exam.id}>
            <Link
              href={`/app/plan/${exam.id}` as never}
              className="hover-row flex w-full items-baseline justify-between gap-4 px-5 py-3 text-left"
            >
              <span className="text-[14px] text-ink-secondary">{exam.name}</span>
              <span className="numeral shrink-0 text-[12.5px] text-ink-tertiary">{exam.examDate}</span>
            </Link>
          </li>
        ))}
      </ul>
    </section>
  );
}

/**
 * Le débit et l'observance, dits une fois.
 *
 * Le bloc ne s'affiche que quand il y a quelque chose à dire : tant que rien n'est mesuré,
 * le plan tourne sur ses valeurs par défaut. De même quand tout va bien.
 */
function Calibration({ adherence, throughput }: { adherence: Adherence; throughput: Throughput }) {
  const { t } = useI18n();
  const level = adherenceLevel(adherence);
  const drifted = throughput.measured && Math.abs(throughput.driftPercent) >= 15;
  if (level === "steady" && !drifted) return null;

  return (
    <section className="rounded-group border border-border bg-surface-muted px-5 py-4">
      <h2 className="section-title">{t("app.plan.calibration.title")}</h2>
      <ul className="mt-1.5 space-y-1 text-[13px] leading-relaxed text-ink-secondary">
        {drifted ? (
          <li>
            {throughput.driftPercent < 0
              ? t("app.plan.calibration.slower", { rate: throughput.cardsPerMinute, percent: Math.abs(throughput.driftPercent) })
              : t("app.plan.calibration.faster", { rate: throughput.cardsPerMinute, percent: throughput.driftPercent })}
          </li>
        ) : null}
        {level !== "steady" ? (
          <li>
            {t(level === "behind" ? "app.plan.calibration.behind" : "app.plan.calibration.slipping", {
              percent: Math.round(adherence.ratio * 100),
              days: adherence.missedDays,
            })}
          </li>
        ) : null}
      </ul>
    </section>
  );
}

function EmptyPlan({ hasCourses }: { hasCourses: boolean }) {
  const { t } = useI18n();
  return (
    <section className="panel p-8 text-center">
      <p className="text-[17px] font-semibold text-ink">{t("app.plan.empty.title")}</p>
      <p className="mx-auto mt-2 max-w-[48ch] text-[14px] leading-relaxed text-ink-secondary">
        {hasCourses ? t("app.plan.empty.body") : t("app.plan.empty.bodyFresh")}
      </p>
      <div className="mt-6">
        <Button className="h-11 px-6" render={<Link href={"/app/plan/nouveau" as never} />}>
          {t("app.newPlan.add")}
        </Button>
      </div>
      <p className="mt-3 text-[12.5px] text-ink-tertiary">{t("app.newPlan.emptyHint")}</p>
    </section>
  );
}
