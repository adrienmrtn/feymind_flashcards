"use client";

import { addDays, startOfDay } from "@micabo/core";

const WEEKDAYS = ["L", "M", "M", "J", "V", "S", "D"];

export interface CalendarExam {
  id: string;
  examDate: string;
  isPast: boolean;
}

export function monthGrid(month: Date): Date[] {
  const first = startOfDay(new Date(month.getFullYear(), month.getMonth(), 1));
  const mondayOffset = (first.getDay() + 6) % 7;
  const start = addDays(first, -mondayOffset);
  return Array.from({ length: 42 }, (_, index) => addDays(start, index));
}

export function ExamCalendar({
  month,
  selected,
  exams,
  onMonth,
  onSelect,
}: {
  month: Date;
  selected: Date | null;
  exams: CalendarExam[];
  onMonth: (next: Date) => void;
  onSelect: (day: Date) => void;
}) {
  const today = startOfDay(new Date());
  const days = monthGrid(month);
  const byDay = new Map<string, CalendarExam[]>();
  for (const exam of exams) {
    const key = exam.examDate;
    const bucket = byDay.get(key) ?? [];
    bucket.push(exam);
    byDay.set(key, bucket);
  }

  const label = month.toLocaleDateString("fr-FR", { month: "long", year: "numeric" });

  return (
    <div className="paper rounded-group bg-surface p-5">
      <div className="mb-4 flex items-center justify-between gap-3">
        <p className="text-[16px] font-semibold capitalize text-ink">{label}</p>
        <div className="flex gap-1">
          <button
            type="button"
            onClick={() => onMonth(new Date(month.getFullYear(), month.getMonth() - 1, 1))}
            className="pressable flex h-8 w-8 items-center justify-center rounded-full bg-surface-muted text-ink-secondary"
            aria-label="Mois précédent"
          >
            ‹
          </button>
          <button
            type="button"
            onClick={() => onMonth(new Date(month.getFullYear(), month.getMonth() + 1, 1))}
            className="pressable flex h-8 w-8 items-center justify-center rounded-full bg-surface-muted text-ink-secondary"
            aria-label="Mois suivant"
          >
            ›
          </button>
        </div>
      </div>

      <div className="grid grid-cols-7 gap-1">
        {WEEKDAYS.map((day, index) => (
          <p key={`${day}-${index}`} className="pb-1 text-center text-[11px] font-semibold text-ink-tertiary">
            {day}
          </p>
        ))}

        {days.map((day) => {
          const key = isoDay(day);
          const marks = byDay.get(key) ?? [];
          const isSelected = selected ? sameDay(selected, day) : false;
          const isToday = sameDay(today, day);
          const outside = day.getMonth() !== month.getMonth();

          return (
            <button
              key={key}
              type="button"
              onClick={() => onSelect(day)}
              className={`flex h-11 flex-col items-center justify-center rounded-button text-[13.5px] transition-colors duration-hover ${
                isSelected
                  ? "bg-accent text-on-ink"
                  : isToday
                    ? "bg-accent-soft text-accent"
                    : "text-ink hover:bg-surface-muted"
              } ${outside && !isSelected ? "opacity-40" : ""}`}
            >
              <span className={`numeral ${isToday || isSelected ? "font-semibold" : ""}`}>
                {day.getDate()}
              </span>
              <span className="mt-0.5 flex h-1.5 gap-0.5">
                {marks.slice(0, 3).map((exam) => (
                  <span
                    key={exam.id}
                    className={`h-1 w-1 rounded-full ${
                      isSelected ? "bg-on-ink" : exam.isPast ? "bg-ink-tertiary" : "bg-caution"
                    }`}
                  />
                ))}
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}

export function isoDay(date: Date): string {
  const local = startOfDay(date);
  const year = local.getFullYear();
  const month = String(local.getMonth() + 1).padStart(2, "0");
  const day = String(local.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

export function sameDay(left: Date, right: Date): boolean {
  return startOfDay(left).getTime() === startOfDay(right).getTime();
}
