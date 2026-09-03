"use client";

import { useMemo, useState } from "react";

import {
  TARGET_SCORE_MAX,
  TARGET_SCORE_MIN,
  averageDailyLoad,
  busiestDay,
  clampTargetScore,
  desiredGradeLabel,
  desiredGradeScale,
  intensityFromTargetScore,
  isProjectionEmpty,
  planExam,
  startOfDay,
  targetScoreFromIntensity,
  type CardState,
  type ExamIntensity,
} from "@micabo/core";

import { ThinkingOrb } from "thinking-orbs";

import { ChoiceRow } from "@/components/onboarding/Scaffold";
import { Slider } from "@/components/ui/slider";
import { deleteExam, saveExam } from "@/lib/actions/exams";
import { useI18n } from "@/lib/i18n/client";
import { localeBcp47, type Translator } from "@/lib/i18n/copy";
import type { UiLocale } from "@/lib/i18n/locales";

import { ExamDayPicker, isoDay } from "./ExamCalendar";

export interface EditorCourse {
  id: string;
  title: string;
  emoji: string;
  cardCount: number;
}

export interface EditorCard {
  id: string;
  courseId: string | null;
  state: CardState;
  intervalDays: number;
  dueDate: string;
  isSuspended: boolean;
}

export interface EditorExam {
  id: string;
  name: string;
  examDate: string;
  intensity: ExamIntensity;
  targetScore: number;
  courseIds: string[];
}

type Step = "jour" | "cours" | "intensite";

const STEPS: Step[] = ["jour", "cours", "intensite"];

const INTENSITY_KEY: Record<ExamIntensity, "light" | "standard" | "intense"> = {
  light: "light",
  standard: "standard",
  intense: "intense",
};

/**
 * Ajouter un examen : **trois questions, jamais plein écran.**
 *
 * Un seul bloc avec nom, date, cours et curseur faisait lire un formulaire. Ici
 * c'est le même geste que le parcours : un écran, une question, un bouton.
 * La date du clic est déjà choisie. On peut la changer.
 */
export function ExamEditor({
  exam,
  date,
  courses,
  cards,
  countryCode,
  onClose,
}: {
  exam: EditorExam | null;
  date: Date;
  courses: EditorCourse[];
  cards: EditorCard[];
  countryCode?: string | null;
  onClose: (outcome?: "created" | "updated" | "deleted") => void;
}) {
  const { t, locale } = useI18n();
  const today = startOfDay(new Date());
  const [step, setStep] = useState<Step>("jour");
  const [examDate, setExamDate] = useState(exam?.examDate ?? isoDay(date));
  const [targetScore, setTargetScore] = useState(() =>
    clampTargetScore(exam?.targetScore ?? targetScoreFromIntensity(exam?.intensity ?? "standard")),
  );
  const intensity = intensityFromTargetScore(targetScore);
  const [selected, setSelected] = useState<string[]>(exam?.courseIds ?? []);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const [pickerMonth, setPickerMonth] = useState(() => monthFrom(exam?.examDate ?? isoDay(date)));

  const chosen = cards.filter(
    (card) => !card.isSuspended && card.courseId && selected.includes(card.courseId),
  );
  const picked = startOfDay(new Date(`${examDate}T12:00:00`));
  const dateOk = picked.getTime() >= today.getTime();
  const index = STEPS.indexOf(step);

  const plan = useMemo(
    () =>
      planExam(
        chosen.map((card) => ({
          id: card.id,
          state: card.state,
          intervalDays: card.intervalDays,
          dueDate: new Date(card.dueDate),
        })),
        new Date(`${examDate}T12:00:00`),
        { intensity },
      ),
    [chosen, examDate, intensity],
  );

  const canContinue =
    step === "jour" ? dateOk : step === "cours" ? selected.length > 0 : selected.length > 0 && dateOk;
  const missingCards = selected.length > 0 && chosen.length === 0;
  const peak = busiestDay(plan.projection);

  function pickDay(day: Date) {
    const start = startOfDay(day);
    if (start.getTime() < today.getTime()) return;
    setExamDate(isoDay(start));
    setPickerMonth(new Date(start.getFullYear(), start.getMonth(), 1));
  }

  function toggle(id: string) {
    setSelected((current) =>
      current.includes(id) ? current.filter((item) => item !== id) : [...current, id],
    );
  }

  function goNext() {
    if (!canContinue) return;
    const following = STEPS[index + 1];
    if (following) {
      setFailure(null);
      setStep(following);
      return;
    }
    void confirm();
  }

  function goBack() {
    const previous = STEPS[index - 1];
    if (previous) setStep(previous);
  }

  async function confirm() {
    setBusy(true);
    setFailure(null);
    const result = await saveExam({
      id: exam?.id,
      name: examName(t, exam, selected, courses),
      examDate,
      intensity,
      targetScore,
      courseIds: selected,
    });
    setBusy(false);
    if (result.status === "error") {
      setFailure(result.message ?? t("app.exams.saveError"));
      return;
    }
    onClose(exam ? "updated" : "created");
  }

  async function remove() {
    if (!exam) return;
    setBusy(true);
    const result = await deleteExam(exam.id);
    setBusy(false);
    if (result.status === "error") {
      setFailure(result.message ?? t("app.exams.deleteError"));
      return;
    }
    onClose("deleted");
  }

  return (
    <div className="fixed inset-0 z-40 flex items-end justify-center p-3 sm:items-center sm:p-6">
      <button
        type="button"
        className="absolute inset-0 bg-ink/35 backdrop-blur-[6px]"
        aria-label={t("app.a11y.close")}
        onClick={() => onClose()}
      />
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="exam-onboarding-title"
        className="relative flex max-h-[min(760px,92svh)] w-full max-w-[560px] flex-col overflow-hidden rounded-[28px] bg-surface shadow-floating"
      >
        <div className="flex items-center justify-between px-6 pt-4 sm:px-7">
          <div className="flex items-center gap-1.5" aria-hidden>
            {STEPS.map((item, position) => (
              <span
                key={item}
                className={`h-1.5 rounded-pill transition-all duration-menu ${
                  position === index
                    ? "w-6 bg-ink"
                    : position < index
                      ? "w-1.5 bg-ink"
                      : "w-1.5 bg-stroke-strong"
                }`}
              />
            ))}
          </div>
          <button
            type="button"
            onClick={() => onClose()}
            className="pressable -mr-1 flex h-9 w-9 items-center justify-center rounded-full text-ink-tertiary hover:bg-canvas"
            aria-label={t("app.a11y.close")}
          >
            <svg aria-hidden viewBox="0 0 20 20" className="h-5 w-5">
              <path
                d="M5 5l10 10M15 5L5 15"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinecap="round"
              />
            </svg>
          </button>
        </div>

        <div className="min-h-0 flex-1 overflow-y-auto px-6 pb-2 pt-4 sm:px-7">
          <div key={step} className="rise">
            {step === "jour" ? (
              <DayStep
                t={t}
                locale={locale}
                picked={picked}
                month={pickerMonth}
                onMonth={setPickerMonth}
                onSelect={pickDay}
              />
            ) : null}
            {step === "cours" ? (
              <CoursesStep t={t} courses={courses} selected={selected} onToggle={toggle} />
            ) : null}
            {step === "intensite" ? (
              <IntensityStep
                t={t}
                targetScore={targetScore}
                countryCode={countryCode}
                onPick={setTargetScore}
                missingCards={missingCards}
                canPreview={selected.length > 0 && !isProjectionEmpty(plan.projection)}
                cardCount={plan.projection.cardCount}
                daily={averageDailyLoad(plan.projection)}
                peak={peak}
                load={plan.projection.load}
              />
            ) : null}
          </div>

          {failure ? (
            <p className="mt-4 text-[13.5px] text-negative" role="alert">
              {failure}
            </p>
          ) : null}
        </div>

        <div className="px-6 pb-6 pt-3 sm:px-7">
          <button
            type="button"
            onClick={goNext}
            disabled={busy || !canContinue}
            className={`pressable flex h-14 w-full items-center justify-center gap-2 rounded-button text-[16px] font-semibold transition-colors duration-hover ${
              busy
                ? "bg-accent text-on-ink"
                : canContinue
                  ? "shiny bg-accent text-on-ink"
                  : "cursor-not-allowed bg-surface-sunken text-ink-tertiary"
            }`}
          >
            {busy && step === "intensite" ? (
              <>
                <ThinkingOrb state="connecting" size={20} theme="dark" />
                {t("app.exams.wait")}
              </>
            ) : step === "intensite" ? (
              exam ? (
                t("app.exams.reschedule")
              ) : (
                t("app.exams.schedule")
              )
            ) : (
              t("app.common.continue")
            )}
          </button>
          {index > 0 ? (
            <button
              type="button"
              onClick={goBack}
              disabled={busy}
              className="pressable mt-2 h-11 w-full rounded-button text-[14px] font-medium text-ink-secondary"
            >
              {t("app.common.back")}
            </button>
          ) : null}
          {exam && step === "intensite" ? (
            <button
              type="button"
              onClick={() => void remove()}
              disabled={busy}
              className="pressable mt-1 h-11 w-full rounded-button text-[14px] font-medium text-negative"
            >
              {t("app.common.delete")}
            </button>
          ) : null}
        </div>
      </div>
    </div>
  );
}

function DayStep({
  t,
  locale,
  picked,
  month,
  onMonth,
  onSelect,
}: {
  t: Translator;
  locale: UiLocale;
  picked: Date;
  month: Date;
  onMonth: (next: Date) => void;
  onSelect: (day: Date) => void;
}) {
  const today = startOfDay(new Date());
  const label = picked.toLocaleDateString(localeBcp47(locale), {
    weekday: "long",
    day: "numeric",
    month: "long",
  });

  return (
    <div>
      <p className="eyebrow text-ink-tertiary">{t("app.exams.examEyebrow")}</p>
      <h2 id="exam-onboarding-title" className="mt-2 text-[26px] font-bold leading-[1.12] text-ink">
        {t("app.exams.whichDay")}
      </h2>
      <p className="mt-3 text-[18px] font-semibold capitalize text-ink">{label}</p>
      <div className="mt-5">
        <ExamDayPicker
          month={month}
          selected={picked}
          minDate={today}
          onMonth={onMonth}
          onSelect={onSelect}
        />
      </div>
    </div>
  );
}

function CoursesStep({
  t,
  courses,
  selected,
  onToggle,
}: {
  t: Translator;
  courses: EditorCourse[];
  selected: string[];
  onToggle: (id: string) => void;
}) {
  return (
    <div>
      <p className="eyebrow text-ink-tertiary">{t("app.exams.coursesEyebrow")}</p>
      <h2 id="exam-onboarding-title" className="mt-2 text-[26px] font-bold leading-[1.12] text-ink">
        {t("app.exams.whichCourses")}
      </h2>
      {courses.length === 0 ? (
        <p className="mt-6 text-[14.5px] leading-relaxed text-ink-secondary">
          {t("app.exams.noCoursesYet")}
        </p>
      ) : (
        <ul className="mt-6 space-y-2">
          {courses.map((course) => (
            <li key={course.id}>
              <ChoiceRow
                emoji={course.emoji}
                title={course.title || t("app.course.untitled")}
                detail={t("app.course.cardCount", { count: course.cardCount })}
                selected={selected.includes(course.id)}
                onSelect={() => onToggle(course.id)}
              />
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

function IntensityStep({
  t,
  targetScore,
  countryCode,
  onPick,
  missingCards,
  canPreview,
  cardCount,
  daily,
  peak,
  load,
}: {
  t: Translator;
  targetScore: number;
  countryCode?: string | null;
  onPick: (value: number) => void;
  missingCards: boolean;
  canPreview: boolean;
  cardCount: number;
  daily: number;
  peak: { offset: number; count: number } | null;
  load: number[];
}) {
  const scale = desiredGradeScale(countryCode);
  const intensity = intensityFromTargetScore(targetScore);

  return (
    <div>
      <p className="eyebrow text-ink-tertiary">{t("app.exams.gradeEyebrow")}</p>
      <h2 id="exam-onboarding-title" className="mt-2 text-[26px] font-bold leading-[1.12] text-ink">
        {t("app.exams.desiredGrade")}
      </h2>
      <p className="mt-6 text-center text-[32px] font-bold leading-none text-ink">
        {desiredGradeLabel(targetScore, countryCode)}
      </p>
      <p className="mt-2 text-center text-[13.5px] text-ink-secondary">
        {t(`app.exams.${INTENSITY_KEY[intensity]}`)}
      </p>
      <div className="mt-6 flex items-center gap-3">
        <span className="numeral w-12 shrink-0 text-[12.5px] text-ink-tertiary">
          {scale.min}
        </span>
        <Slider
          className="min-w-0 flex-1"
          min={TARGET_SCORE_MIN}
          max={TARGET_SCORE_MAX}
          step={1}
          value={targetScore}
          onValueChange={(value) => onPick(clampTargetScore(Number(value)))}
          aria-label={t("app.exams.desiredGrade")}
        />
        <span className="numeral w-12 shrink-0 text-right text-[12.5px] text-ink-tertiary">
          {scale.max}
        </span>
      </div>

      {missingCards ? (
        <p className="mt-4 text-[13.5px] leading-relaxed text-caution">
          {t("app.exams.missingCards")}
        </p>
      ) : null}

      {canPreview ? (
        <div className="mt-5 rounded-group bg-canvas p-4">
          <p className="text-[13.5px] text-ink-secondary">
            {peak
              ? t("app.exams.planPeak", {
                  cards: t("app.course.cardCount", { count: cardCount }),
                  daily,
                  peak: peak.count,
                })
              : t("app.exams.planPreview", {
                  cards: t("app.course.cardCount", { count: cardCount }),
                  daily,
                })}
          </p>
          <div className="mt-3 flex h-10 items-end gap-0.5">
            {load.map((count, position) => {
              const max = Math.max(1, ...load);
              return (
                <span
                  key={position}
                  className={`min-w-0 flex-1 rounded-t-sm ${
                    peak && position === peak.offset ? "bg-caution" : "bg-ink/40"
                  }`}
                  style={{ height: `${Math.max(8, (count / max) * 100)}%` }}
                />
              );
            })}
          </div>
        </div>
      ) : null}
    </div>
  );
}

function examName(
  t: Translator,
  exam: EditorExam | null,
  courseIds: string[],
  courses: EditorCourse[],
): string {
  const existing = exam?.name.trim();
  if (existing) return existing;
  const titles = courseIds
    .map((id) => courses.find((course) => course.id === id)?.title.trim())
    .filter((title): title is string => Boolean(title));
  if (titles.length === 0) return t("app.exams.defaultName");
  return titles.slice(0, 2).join(" · ");
}

function monthFrom(iso: string): Date {
  const day = startOfDay(new Date(`${iso}T12:00:00`));
  return new Date(day.getFullYear(), day.getMonth(), 1);
}
