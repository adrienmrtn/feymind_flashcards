import type { WeekDayLoad } from "@micabo/core";

import { Card, CardHeader, CardPanel, CardTitle } from "@/components/ui/card";

const BAR_MAX = 52;

/**
 * La semaine glissante du tableau de bord.
 *
 * Sept colonnes, trois jours derrière et trois devant. Chaque barre empile
 * ce qui a déjà été révisé ce jour-là et ce qui reste dû — les jours passés
 * portent donc un volume, plus seulement un point.
 */
export function WeekStrip({ days }: { days: readonly WeekDayLoad[] }) {
  const peak = Math.max(1, ...days.map(dayTotal));

  return (
    <Card className="h-full">
      <CardHeader className="pb-2">
        <CardTitle className="text-[15px] font-semibold text-ink">Semaine</CardTitle>
      </CardHeader>
      <CardPanel className="flex flex-1 flex-col justify-center pt-0">
        <div className="mx-auto grid w-full max-w-[22rem] grid-cols-7 gap-1 sm:gap-1.5">
          {days.map((day) => (
            <DayCell key={day.offset} day={day} peak={peak} />
          ))}
        </div>
        <p className="mt-3 flex items-center justify-center gap-3 text-[12px] text-ink-tertiary">
          <LegendSwatch className="bg-ink" />
          révisées
          <LegendSwatch className="bg-ink/25" />
          à réviser
        </p>
      </CardPanel>
    </Card>
  );
}

function DayCell({ day, peak }: { day: WeekDayLoad; peak: number }) {
  const today = day.offset === 0;
  const reviewed = day.reviewCount;
  const due = day.planned;
  const total = reviewed + due;
  const reviewedHeight = heightFor(reviewed, peak);
  const dueHeight = heightFor(due, peak);

  return (
    <div
      className={`flex flex-col items-center rounded-lg px-0.5 py-2 sm:px-1 ${
        today ? "bg-surface-muted" : ""
      }`}
      aria-label={`${labelFor(day, today)} : ${reviewed} révisée${reviewed > 1 ? "s" : ""}, ${due} à réviser`}
    >
      <p
        className={`text-[10px] font-semibold uppercase tracking-wide sm:text-[11px] ${
          today ? "text-ink" : "text-ink-tertiary"
        }`}
      >
        {today ? "auj." : weekday(day.date)}
      </p>
      <p className="numeral mt-0.5 text-[13px] font-semibold text-ink sm:text-[14px]">
        {day.date.getDate()}
      </p>
      <div className="mt-2 flex h-[52px] w-full items-end justify-center">
        <div className="flex w-3.5 flex-col-reverse overflow-hidden rounded-t-[2px] sm:w-4">
          {reviewed > 0 ? (
            <div className="bg-ink" style={{ height: `${reviewedHeight}px` }} />
          ) : null}
          {due > 0 ? (
            <div
              className={today ? "bg-ink/40" : "bg-ink/20"}
              style={{ height: `${dueHeight}px` }}
            />
          ) : null}
          {total === 0 ? <div className="h-[3px] bg-stroke-strong" /> : null}
        </div>
      </div>
      <p className="numeral mt-1 text-[13px] font-bold text-ink sm:text-[15px]">{total}</p>
    </div>
  );
}

function LegendSwatch({ className }: { className: string }) {
  return <span aria-hidden className={`inline-block h-2 w-2 rounded-[1px] ${className}`} />;
}

function dayTotal(day: WeekDayLoad): number {
  return day.planned + day.reviewCount;
}

function heightFor(count: number, peak: number): number {
  if (count <= 0) return 0;
  return Math.max(6, Math.round((count / peak) * BAR_MAX));
}

function labelFor(day: WeekDayLoad, today: boolean): string {
  if (today) return "Aujourd'hui";
  return weekday(day.date);
}

function weekday(date: Date): string {
  return date.toLocaleDateString("fr-FR", { weekday: "short" }).replace(".", "");
}
