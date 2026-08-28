"use client";

import { useMemo, useState } from "react";

import {
  averageDailyLoad,
  busiestDay,
  desiredGradeLabel,
  desiredGradeScale,
  gradeIndexFor,
  intensityFromGradeIndex,
  isProjectionEmpty,
  planExam,
  startOfDay,
  type CardState,
  type ExamIntensity,
} from "@micabo/core";

import { ThinkingOrb } from "thinking-orbs";

import { ChoiceRow } from "@/components/onboarding/Scaffold";
import { Slider } from "@/components/ui/slider";
import { deleteExam, saveExam } from "@/lib/actions/exams";

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
  courseIds: string[];
}

type Step = "jour" | "cours" | "intensite";

const STEPS: Step[] = ["jour", "cours", "intensite"];

const INTENSITY_DETAIL: Record<ExamIntensity, string> = {
  light: "Deux passages, pour un chapitre déjà su.",
  standard: "Trois passages, le rythme d'un contrôle.",
  intense: "Quatre passages, quand ça compte vraiment.",
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
  onClose: () => void;
}) {
  const today = startOfDay(new Date());
  const [step, setStep] = useState<Step>("jour");
  const [examDate, setExamDate] = useState(exam?.examDate ?? isoDay(date));
  const [intensity, setIntensity] = useState<ExamIntensity>(exam?.intensity ?? "standard");
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
      name: examName(exam, selected, courses),
      examDate,
      intensity,
      courseIds: selected,
    });
    setBusy(false);
    if (result.status === "error") {
      setFailure(result.message ?? "L'examen n'a pas pu être enregistré.");
      return;
    }
    onClose();
  }

  async function remove() {
    if (!exam) return;
    setBusy(true);
    const result = await deleteExam(exam.id);
    setBusy(false);
    if (result.status === "error") {
      setFailure(result.message ?? "Impossible de supprimer.");
      return;
    }
    onClose();
  }

  return (
    <div className="fixed inset-0 z-40 flex items-end justify-center p-3 sm:items-center sm:p-6">
      <button
        type="button"
        className="absolute inset-0 bg-ink/35 backdrop-blur-[6px]"
        aria-label="Fermer"
        onClick={onClose}
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
            onClick={onClose}
            className="pressable -mr-1 flex h-9 w-9 items-center justify-center rounded-full text-ink-tertiary hover:bg-canvas"
            aria-label="Fermer"
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
                picked={picked}
                month={pickerMonth}
                onMonth={setPickerMonth}
                onSelect={pickDay}
              />
            ) : null}
            {step === "cours" ? (
              <CoursesStep courses={courses} selected={selected} onToggle={toggle} />
            ) : null}
            {step === "intensite" ? (
              <IntensityStep
                intensity={intensity}
                countryCode={countryCode}
                onPick={setIntensity}
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
                ? "bg-ink text-on-ink"
                : canContinue
                  ? "shiny bg-ink text-on-ink"
                  : "cursor-not-allowed bg-surface-sunken text-ink-tertiary"
            }`}
          >
            {busy && step === "intensite" ? (
              <>
                <ThinkingOrb state="connecting" size={20} theme="dark" />
                Un instant
              </>
            ) : step === "intensite" ? (
              exam ? (
                "Replanifier"
              ) : (
                "Planifier l'examen"
              )
            ) : (
              "Continuer"
            )}
          </button>
          {index > 0 ? (
            <button
              type="button"
              onClick={goBack}
              disabled={busy}
              className="pressable mt-2 h-11 w-full rounded-button text-[14px] font-medium text-ink-secondary"
            >
              Retour
            </button>
          ) : null}
          {exam && step === "intensite" ? (
            <button
              type="button"
              onClick={() => void remove()}
              disabled={busy}
              className="pressable mt-1 h-11 w-full rounded-button text-[14px] font-medium text-negative"
            >
              Supprimer
            </button>
          ) : null}
        </div>
      </div>
    </div>
  );
}

function DayStep({
  picked,
  month,
  onMonth,
  onSelect,
}: {
  picked: Date;
  month: Date;
  onMonth: (next: Date) => void;
  onSelect: (day: Date) => void;
}) {
  const today = startOfDay(new Date());
  const label = picked.toLocaleDateString("fr-FR", {
    weekday: "long",
    day: "numeric",
    month: "long",
  });

  return (
    <div>
      <p className="eyebrow text-ink-tertiary">📅 Examen</p>
      <h2 id="exam-onboarding-title" className="mt-2 text-[26px] font-bold leading-[1.12] text-ink">
        Quel jour ?
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
  courses,
  selected,
  onToggle,
}: {
  courses: EditorCourse[];
  selected: string[];
  onToggle: (id: string) => void;
}) {
  return (
    <div>
      <p className="eyebrow text-ink-tertiary">📚 Cours</p>
      <h2 id="exam-onboarding-title" className="mt-2 text-[26px] font-bold leading-[1.12] text-ink">
        Quels cours intégrés ?
      </h2>
      {courses.length === 0 ? (
        <p className="mt-6 text-[14.5px] leading-relaxed text-ink-secondary">
          Importe d&apos;abord un cours. Sans cartes, il n&apos;y a rien à replanifier.
        </p>
      ) : (
        <ul className="mt-6 space-y-2">
          {courses.map((course) => (
            <li key={course.id}>
              <ChoiceRow
                emoji={course.emoji}
                title={course.title || "Sans titre"}
                detail={`${course.cardCount} carte${course.cardCount > 1 ? "s" : ""}`}
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
  intensity,
  countryCode,
  onPick,
  missingCards,
  canPreview,
  cardCount,
  daily,
  peak,
  load,
}: {
  intensity: ExamIntensity;
  countryCode?: string | null;
  onPick: (value: ExamIntensity) => void;
  missingCards: boolean;
  canPreview: boolean;
  cardCount: number;
  daily: number;
  peak: { offset: number; count: number } | null;
  load: number[];
}) {
  const scale = desiredGradeScale(countryCode);

  return (
    <div>
      <p className="eyebrow text-ink-tertiary">Note</p>
      <h2 id="exam-onboarding-title" className="mt-2 text-[26px] font-bold leading-[1.12] text-ink">
        Note souhaitée
      </h2>
      <p className="mt-6 text-center text-[32px] font-bold leading-none text-ink">
        {desiredGradeLabel(intensity, countryCode)}
      </p>
      <p className="mt-2 text-center text-[13.5px] text-ink-secondary">
        {INTENSITY_DETAIL[intensity]}
      </p>
      <div className="mt-6 px-1">
        <Slider
          min={0}
          max={2}
          step={1}
          value={gradeIndexFor(intensity)}
          onValueChange={(value) => onPick(intensityFromGradeIndex(Number(value)))}
          aria-label="Note souhaitée"
        />
        <div className="mt-2 flex justify-between text-[12.5px] text-ink-tertiary">
          <span>{scale.min}</span>
          <span>{scale.max}</span>
        </div>
      </div>

      {missingCards ? (
        <p className="mt-4 text-[13.5px] leading-relaxed text-caution">
          Ces cours n&apos;ont pas encore de cartes. Le plan se posera au premier paquet.
        </p>
      ) : null}

      {canPreview ? (
        <div className="mt-5 rounded-group bg-canvas p-4">
          <p className="text-[13.5px] text-ink-secondary">
            <span className="numeral font-semibold text-ink">{cardCount}</span> cartes ·{" "}
            <span className="numeral font-semibold text-ink">{daily}</span> révisions / jour
            {peak ? (
              <>
                {" "}
                · pic de <span className="numeral font-semibold text-ink">{peak.count}</span>
              </>
            ) : null}
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

function examName(exam: EditorExam | null, courseIds: string[], courses: EditorCourse[]): string {
  const existing = exam?.name.trim();
  if (existing) return existing;
  const titles = courseIds
    .map((id) => courses.find((course) => course.id === id)?.title.trim())
    .filter((title): title is string => Boolean(title));
  if (titles.length === 0) return "Examen";
  return titles.slice(0, 2).join(" · ");
}

function monthFrom(iso: string): Date {
  const day = startOfDay(new Date(`${iso}T12:00:00`));
  return new Date(day.getFullYear(), day.getMonth(), 1);
}
