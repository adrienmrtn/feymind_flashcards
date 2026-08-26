"use client";

import { useMemo, useState } from "react";

import {
  EXAM_INTENSITIES,
  EXAM_INTENSITY_EMOJIS,
  EXAM_INTENSITY_LABELS,
  averageDailyLoad,
  busiestDay,
  isProjectionEmpty,
  planExam,
  type CardState,
  type ExamIntensity,
} from "@micabo/core";

import { deleteExam, saveExam } from "@/lib/actions/exams";

import { isoDay } from "./ExamCalendar";

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

export function ExamEditor({
  exam,
  date,
  courses,
  cards,
  onClose,
}: {
  exam: EditorExam | null;
  date: Date;
  courses: EditorCourse[];
  cards: EditorCard[];
  onClose: () => void;
}) {
  const [name, setName] = useState(exam?.name ?? "");
  const [examDate, setExamDate] = useState(exam?.examDate ?? isoDay(date));
  const [intensity, setIntensity] = useState<ExamIntensity>(exam?.intensity ?? "standard");
  const [selected, setSelected] = useState<string[]>(exam?.courseIds ?? []);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);

  const chosen = cards.filter(
    (card) => !card.isSuspended && card.courseId && selected.includes(card.courseId),
  );

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

  const canConfirm = selected.length > 0;
  const missingCards = selected.length > 0 && chosen.length === 0;
  const peak = busiestDay(plan.projection);

  async function confirm() {
    setBusy(true);
    setFailure(null);
    const result = await saveExam({
      id: exam?.id,
      name,
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

  function toggle(id: string) {
    setSelected((current) =>
      current.includes(id) ? current.filter((item) => item !== id) : [...current, id],
    );
  }

  const intensityIndex = EXAM_INTENSITIES.indexOf(intensity);

  return (
    <div className="fixed inset-0 z-40 flex items-end justify-center bg-ink/35 p-4 sm:items-center">
      <button type="button" className="absolute inset-0" aria-label="Fermer" onClick={onClose} />
      <div className="relative max-h-[92svh] w-full max-w-[520px] overflow-y-auto rounded-sheet bg-canvas p-6 shadow-floating">
        <div className="flex items-start justify-between gap-4">
          <div>
            <p className="eyebrow text-ink-tertiary">{exam ? "Modifier" : "Nouveau"}</p>
            <h2 className="mt-1 text-[22px] font-bold text-ink">
              {exam ? "Replanifier l'examen" : "Ajouter un examen"}
            </h2>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="pressable text-[18px] text-ink-tertiary"
            aria-label="Fermer"
          >
            ✕
          </button>
        </div>

        <label className="mt-6 block">
          <span className="eyebrow text-ink-tertiary">Nom</span>
          <input
            value={name}
            onChange={(event) => setName(event.target.value)}
            placeholder="Partiel de maths"
            className="mt-2 h-12 w-full rounded-button bg-surface px-4 text-[15px] text-ink outline-none"
          />
        </label>

        <label className="mt-4 block">
          <span className="eyebrow text-ink-tertiary">Date</span>
          <input
            type="date"
            value={examDate}
            onChange={(event) => setExamDate(event.target.value)}
            className="mt-2 h-12 w-full rounded-button bg-surface px-4 text-[15px] text-ink outline-none"
          />
        </label>

        <fieldset className="mt-5">
          <legend className="eyebrow text-ink-tertiary">Cours de cet examen</legend>
          <ul className="mt-2 overflow-hidden rounded-group bg-surface">
            {courses.map((course) => {
              const on = selected.includes(course.id);
              return (
                <li key={course.id} className="border-t border-hairline first:border-t-0">
                  <button
                    type="button"
                    onClick={() => toggle(course.id)}
                    className={`hover-row flex w-full items-center gap-3 px-4 py-3 text-left ${
                      on ? "bg-accent-soft" : ""
                    }`}
                  >
                    <span aria-hidden className="text-[18px]">
                      {course.emoji}
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-[14.5px] font-medium text-ink">
                        {course.title || "Sans titre"}
                      </span>
                      <span className="text-[12.5px] text-ink-tertiary">
                        {course.cardCount} carte{course.cardCount > 1 ? "s" : ""}
                      </span>
                    </span>
                    <span
                      className={`h-5 w-5 rounded-full border ${
                        on ? "border-accent bg-accent" : "border-stroke"
                      }`}
                    />
                  </button>
                </li>
              );
            })}
          </ul>
        </fieldset>

        <div className="mt-6">
          <p className="eyebrow text-ink-tertiary">Intensité</p>
          <div className="mt-3 flex flex-col items-center rounded-group bg-surface px-5 py-5">
            <span key={intensity} className="emoji-pop text-[42px]" aria-hidden>
              {EXAM_INTENSITY_EMOJIS[intensity]}
            </span>
            <p className="mt-2 text-[16px] font-semibold text-ink">
              {EXAM_INTENSITY_LABELS[intensity]}
            </p>
            <input
              type="range"
              min={0}
              max={2}
              step={1}
              value={intensityIndex}
              onChange={(event) => setIntensity(EXAM_INTENSITIES[Number(event.target.value)]!)}
              className="mt-4 w-full accent-[var(--color-accent)]"
              aria-label="Intensité de l'examen"
            />
            <div className="mt-1 flex w-full justify-between text-[11px] text-ink-tertiary">
              {EXAM_INTENSITIES.map((value) => (
                <span key={value}>{EXAM_INTENSITY_LABELS[value]}</span>
              ))}
            </div>
          </div>
        </div>

        {missingCards ? (
          <p className="mt-4 text-[13.5px] leading-relaxed text-caution">
            Ces cours n&apos;ont pas encore de cartes. Le plan se posera au premier paquet.
          </p>
        ) : null}

        {canConfirm && !isProjectionEmpty(plan.projection) ? (
          <div className="mt-5 rounded-group bg-surface p-4">
            <p className="text-[13.5px] text-ink-secondary">
              <span className="numeral font-semibold text-ink">{plan.projection.cardCount}</span>{" "}
              cartes ·{" "}
              <span className="numeral font-semibold text-ink">{averageDailyLoad(plan.projection)}</span>{" "}
              révisions / jour
              {peak ? (
                <>
                  {" "}
                  · pic de <span className="numeral font-semibold text-ink">{peak.count}</span>
                </>
              ) : null}
            </p>
            <div className="mt-3 flex h-10 items-end gap-0.5">
              {plan.projection.load.map((count, index) => {
                const max = Math.max(1, ...plan.projection.load);
                return (
                  <span
                    key={index}
                    className={`min-w-0 flex-1 rounded-t-sm ${
                      peak && index === peak.offset ? "bg-caution" : "bg-accent/70"
                    }`}
                    style={{ height: `${Math.max(8, (count / max) * 100)}%` }}
                  />
                );
              })}
            </div>
          </div>
        ) : null}

        {failure ? (
          <p className="mt-4 text-[13.5px] text-negative" role="alert">
            {failure}
          </p>
        ) : null}

        <button
          type="button"
          onClick={confirm}
          disabled={busy || !canConfirm}
          className="pressable mt-6 h-12 w-full rounded-button bg-ink text-[15px] font-semibold text-on-ink disabled:opacity-40"
        >
          {exam ? "Replanifier" : "Planifier l'examen"}
        </button>

        {exam ? (
          <button
            type="button"
            onClick={remove}
            disabled={busy}
            className="pressable mt-2 h-11 w-full rounded-button text-[14px] font-medium text-negative"
          >
            Supprimer
          </button>
        ) : null}
      </div>
    </div>
  );
}
