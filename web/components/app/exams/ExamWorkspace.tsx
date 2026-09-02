"use client";

import { useCallback, useMemo, useState } from "react";

import {
  dayDifference,
  examCountdownLabel,
  examUrgency,
  startOfDay,
  type ExamInsight,
  type ExamIntensity,
} from "@micabo/core";

import { Toast } from "@/components/app/Toast";

import { ExamCalendar, isoDay, sameDay, type CalendarExam } from "./ExamCalendar";
import { ExamEditor, type EditorCard, type EditorCourse, type EditorExam } from "./ExamEditor";
import { ExamInsightCard } from "./ExamInsightCard";

export interface WorkspaceExam {
  id: string;
  name: string;
  examDate: string;
  intensity: string;
  targetScore: number;
  courseIds: string[];
  isPlanned: boolean;
}

export function ExamWorkspace({
  exams,
  courses,
  cards,
  insights,
  countryCode,
}: {
  exams: WorkspaceExam[];
  courses: EditorCourse[];
  cards: EditorCard[];
  insights: ExamInsight[];
  countryCode?: string | null;
}) {
  const today = startOfDay(new Date());
  const [month, setMonth] = useState(() => new Date(today.getFullYear(), today.getMonth(), 1));
  const [selected, setSelected] = useState<Date | null>(null);
  const [editing, setEditing] = useState<{ exam: EditorExam | null; date: Date } | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const dismissNotice = useCallback(() => setNotice(null), []);

  const calendarExams: CalendarExam[] = exams.map((exam) => ({
    id: exam.id,
    name: exam.name,
    examDate: exam.examDate,
    isPast: dayDifference(today, startOfDay(new Date(`${exam.examDate}T12:00:00`))) < 0,
  }));

  const dated = useMemo(
    () =>
      exams
        .map((exam) => ({
          ...exam,
          days: dayDifference(today, startOfDay(new Date(`${exam.examDate}T12:00:00`))),
        }))
        .sort((left, right) => left.days - right.days),
    [exams, today],
  );

  const upcoming = dated.filter((exam) => exam.days >= 0);
  const past = dated.filter((exam) => exam.days < 0);
  const titles = new Map(courses.map((course) => [course.id, course.title]));
  const insightById = new Map(insights.map((insight) => [insight.id, insight]));

  const onDay = selected
    ? dated.filter((exam) => exam.examDate === isoDay(selected))
    : [];

  function pickDay(day: Date) {
    const start = startOfDay(day);
    const again = selected && sameDay(selected, start);
    setSelected(again ? null : start);
    if (start.getMonth() !== month.getMonth() || start.getFullYear() !== month.getFullYear()) {
      setMonth(new Date(start.getFullYear(), start.getMonth(), 1));
    }

    // Un jour à venir sans examen : on ouvre tout de suite la feuille, comme demandé.
    const key = isoDay(start);
    const already = exams.some((exam) => exam.examDate === key);
    if (!again && start.getTime() >= today.getTime() && !already) {
      setEditing({ exam: null, date: start });
    }
  }

  function openNew() {
    setEditing({ exam: null, date: selected && selected.getTime() >= today.getTime() ? selected : today });
  }

  function openExisting(exam: WorkspaceExam) {
    setEditing({
      exam: {
        id: exam.id,
        name: exam.name,
        examDate: exam.examDate,
        intensity: asIntensity(exam.intensity),
        targetScore: exam.targetScore,
        courseIds: exam.courseIds,
      },
      date: startOfDay(new Date(`${exam.examDate}T12:00:00`)),
    });
  }

  return (
    <>
      <div data-tour="examens-calendrier">
        <ExamCalendar
          month={month}
          selected={selected}
          exams={calendarExams}
          onMonth={setMonth}
          onSelect={pickDay}
        />
      </div>

      <p className="mt-3 text-center text-[12.5px] text-ink-secondary">
        Choisis un jour pour y poser un examen.
      </p>

      <button
        type="button"
        onClick={openNew}
        data-tour="examens-ajouter"
        className="pressable hover-tile mt-5 flex h-12 w-full items-center justify-center gap-2 rounded-button bg-accent text-[15px] font-semibold text-on-ink"
      >
        Ajouter un examen
      </button>

      {selected && onDay.length > 0 ? (
        <section className="mt-8">
          <p className="eyebrow mb-3 text-ink-tertiary">
            {selected.toLocaleDateString("fr-FR", {
              weekday: "long",
              day: "numeric",
              month: "long",
            })}
          </p>
          <ul className="space-y-2">
            {onDay.map((exam) => (
              <ExamRow
                key={exam.id}
                name={exam.name}
                days={exam.days}
                courses={courseLine(exam.courseIds, titles)}
                onClick={() => openExisting(exam)}
              />
            ))}
          </ul>
        </section>
      ) : null}

      {upcoming.length > 0 ? (
        <section className="mt-10">
          <p className="eyebrow mb-3 text-ink-tertiary">À venir</p>
          <div className={`grid min-w-0 gap-4 ${upcoming.length > 1 ? "lg:grid-cols-2" : ""}`}>
            {upcoming.map((exam) => {
              const insight = insightById.get(exam.id);
              return insight ? (
                <ExamInsightCard
                  key={exam.id}
                  insight={insight}
                  onClick={() => openExisting(exam)}
                />
              ) : (
                <ExamRow
                  key={exam.id}
                  name={exam.name}
                  days={exam.days}
                  courses={courseLine(exam.courseIds, titles)}
                  onClick={() => openExisting(exam)}
                />
              );
            })}
          </div>
        </section>
      ) : (
        <p className="mt-4 text-sm text-ink-secondary">
          {courses.length === 0
            ? "Importe un cours avant de poser une date."
            : "Aucune date pour l'instant. Choisis un jour dans le calendrier."}
        </p>
      )}

      {past.length > 0 ? (
        <section className="mt-10">
          <p className="mb-3 text-[13px] font-medium text-muted-foreground">Passés</p>
          <ul className="divide-y divide-hairline overflow-hidden rounded-2xl border border-border bg-card">
            {past.map((exam) => (
              <li key={exam.id}>
                <button
                  type="button"
                  onClick={() => openExisting(exam)}
                  className="hover-row flex w-full items-baseline justify-between gap-4 px-5 py-3.5 text-left"
                >
                  <span className="text-[14.5px] text-ink-secondary">{exam.name}</span>
                  <span className="shrink-0 text-[13px] text-ink-tertiary">{exam.examDate}</span>
                </button>
              </li>
            ))}
          </ul>
        </section>
      ) : null}

      {editing ? (
        <ExamEditor
          exam={editing.exam}
          date={editing.date}
          courses={courses}
          cards={cards}
          countryCode={countryCode}
          onClose={(outcome) => {
            setEditing(null);
            if (outcome === "created") setNotice("Examen rajouté");
          }}
        />
      ) : null}

      {notice ? <Toast message={notice} onGone={dismissNotice} /> : null}
    </>
  );
}

function ExamRow({
  name,
  days,
  courses,
  onClick,
}: {
  name: string;
  days: number;
  courses: string;
  onClick: () => void;
}) {
  const urgency = examUrgency(days);
  const tone =
    urgency === "critical"
      ? "bg-negative-soft text-negative"
      : urgency === "soon"
        ? "bg-caution-soft text-caution"
        : urgency === "upcoming"
          ? "bg-info-soft text-info"
          : "bg-surface-muted text-ink-secondary";

  return (
    <li>
      <button
        type="button"
        onClick={onClick}
        className="flex w-full min-w-0 items-center justify-between gap-3 overflow-hidden rounded-2xl border border-border bg-card px-4 py-4 text-left sm:gap-4 sm:px-5"
      >
        <span className="min-w-0">
          <span className="block truncate text-[15.5px] font-semibold text-ink">
            {name}
          </span>
          <span className="mt-0.5 block truncate text-[12.5px] text-ink-secondary">
            {courses}
          </span>
        </span>
        <span className={`shrink-0 rounded-pill px-2.5 py-1 text-[12px] font-semibold ${tone}`}>
          {examCountdownLabel(days)}
        </span>
      </button>
    </li>
  );
}

function courseLine(ids: string[], titles: Map<string, string>): string {
  const names = ids.map((id) => titles.get(id)).filter(Boolean);
  return names.length > 0 ? names.join(", ") : "Aucun cours rattaché";
}

function asIntensity(value: string): ExamIntensity {
  return value === "light" || value === "intense" || value === "standard" ? value : "standard";
}
