"use client";

import { addDays, startOfDay } from "@micabo/core";

const WEEKDAYS = [
  { short: "L", label: "Lundi" },
  { short: "M", label: "Mardi" },
  { short: "M", label: "Mercredi" },
  { short: "J", label: "Jeudi" },
  { short: "V", label: "Vendredi" },
  { short: "S", label: "Samedi" },
  { short: "D", label: "Dimanche" },
] as const;

export interface CalendarExam {
  id: string;
  name: string;
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
    <div className="rounded-2xl border border-border bg-card p-4 shadow-xs/5 sm:p-5">
      <CalendarHeader label={label} month={month} onMonth={onMonth} />

      <div className="grid grid-cols-7 gap-1 overflow-hidden">
        {WEEKDAYS.map((day, index) => (
          <p
            key={`${day.label}-${index}`}
            aria-label={day.label}
            className="pb-1 text-center text-[11px] font-semibold text-ink-tertiary"
          >
            {day.short}
          </p>
        ))}

        {days.map((day) => {
          const key = isoDay(day);
          const marks = byDay.get(key) ?? [];
          const isSelected = selected ? sameDay(selected, day) : false;
          const isToday = sameDay(today, day);
          const outside = day.getMonth() !== month.getMonth();
          const extras = Math.max(0, marks.length - 1);
          const first = marks[0];

          return (
            <button
              key={key}
              type="button"
              onClick={() => onSelect(day)}
              aria-label={calendarDayLabel(day, marks)}
              className={`flex min-h-[3.75rem] min-w-0 w-full flex-col items-center overflow-hidden rounded-button px-0.5 transition-colors duration-hover sm:min-h-[4.5rem] sm:px-1 ${
                first ? "pb-1 pt-1" : "justify-center"
              } ${
                isSelected
                  ? "bg-ink text-on-ink"
                  : isToday
                    ? "bg-surface-muted text-ink"
                    : "text-ink hover:bg-surface-muted"
              } ${outside && !isSelected ? "opacity-40" : ""}`}
            >
              <span
                className={`numeral flex h-6 w-full shrink-0 items-center justify-center tracking-normal text-[12.5px] leading-none sm:text-[13.5px] ${
                  isToday || isSelected ? "font-semibold" : ""
                }`}
              >
                {day.getDate()}
              </span>
              {first ? (
                <span className="flex min-h-0 min-w-0 w-full flex-1 flex-col items-stretch gap-0.5 overflow-hidden">
                  <span
                    title={
                      extras > 0
                        ? `${first.name.trim() || "Examen"} · +${extras}`
                        : first.name.trim() || "Examen"
                    }
                    className={`block min-w-0 w-full max-w-full truncate rounded-pill px-1 py-0.5 text-center text-[9px] font-semibold leading-tight sm:text-[11px] ${
                      isSelected
                        ? "bg-on-ink/18 text-on-ink"
                        : first.isPast
                          ? "bg-surface-muted text-ink-tertiary"
                          : "bg-caution-soft text-caution"
                    }`}
                  >
                    {first.name.trim() || "Examen"}
                  </span>
                  {extras > 0 ? (
                    <span
                      className={`px-1 text-center text-[8px] font-semibold sm:text-[10px] ${
                        isSelected ? "text-on-ink/80" : "text-ink-tertiary"
                      }`}
                    >
                      +{extras}
                    </span>
                  ) : null}
                </span>
              ) : null}
            </button>
          );
        })}
      </div>
    </div>
  );
}

/**
 * Le calendrier du premier écran : un jour proposé, qu'on peut changer.
 * Plus compact que la grille des examens, parce qu'il vit dans la carte.
 */
export function ExamDayPicker({
  month,
  selected,
  minDate,
  onMonth,
  onSelect,
}: {
  month: Date;
  selected: Date;
  minDate?: Date;
  onMonth: (next: Date) => void;
  onSelect: (day: Date) => void;
}) {
  const today = startOfDay(new Date());
  const floor = minDate ? startOfDay(minDate) : undefined;
  const days = monthGrid(month);
  const label = month.toLocaleDateString("fr-FR", { month: "long", year: "numeric" });

  return (
    <div>
      <CalendarHeader label={label} month={month} onMonth={onMonth} />
      <div className="grid grid-cols-7 gap-1">
        {WEEKDAYS.map((day, index) => (
          <p
            key={`${day.label}-${index}`}
            aria-label={day.label}
            className="pb-1 text-center text-[11px] font-semibold text-ink-tertiary"
          >
            {day.short}
          </p>
        ))}
        {days.map((day) => {
          const key = isoDay(day);
          const isSelected = sameDay(selected, day);
          const isToday = sameDay(today, day);
          const outside = day.getMonth() !== month.getMonth();
          const blocked = floor ? day.getTime() < floor.getTime() : false;

          return (
            <button
              key={key}
              type="button"
              disabled={blocked}
              onClick={() => onSelect(day)}
              aria-label={day.toLocaleDateString("fr-FR", {
                weekday: "long",
                day: "numeric",
                month: "long",
              })}
              className={`flex h-10 w-full items-center justify-center rounded-button text-[13.5px] leading-none transition-colors duration-hover ${
                isSelected
                  ? "bg-ink font-semibold text-on-ink"
                  : blocked
                    ? "cursor-not-allowed text-ink-tertiary/50"
                    : isToday
                      ? "bg-surface-muted font-semibold text-ink"
                      : "text-ink hover:bg-surface-muted"
              } ${outside && !isSelected && !blocked ? "opacity-40" : ""}`}
            >
              <span className="numeral tracking-normal">{day.getDate()}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
}

function CalendarHeader({
  label,
  month,
  onMonth,
}: {
  label: string;
  month: Date;
  onMonth: (next: Date) => void;
}) {
  return (
    <div className="mb-3 flex items-center justify-between gap-3">
      <p className="text-[16px] font-semibold capitalize text-ink">📅 {label}</p>
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
  );
}

function calendarDayLabel(day: Date, marks: CalendarExam[]): string {
  const date = day.toLocaleDateString("fr-FR", {
    weekday: "long",
    day: "numeric",
    month: "long",
  });
  if (marks.length === 0) return date;
  const names = marks.map((exam) => exam.name.trim() || "Examen").join(", ");
  return `${date}, ${names}`;
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
