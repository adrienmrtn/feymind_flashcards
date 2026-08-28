import type { WeekDayLoad } from "@micabo/core";

import { Card, CardHeader, CardPanel, CardTitle } from "@/components/ui/card";

/**
 * La semaine glissante du tableau de bord.
 *
 * Sept colonnes, trois jours derrière et trois devant. Le chiffre est le
 * nombre de cartes encore dues ce jour-là - en direct, pas une moyenne.
 */
export function WeekStrip({ days }: { days: readonly WeekDayLoad[] }) {
  const peak = Math.max(1, ...days.map((day) => day.planned));

  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-[15px] font-semibold text-ink">Semaine</CardTitle>
      </CardHeader>
      <CardPanel className="pt-0">
        <div className="grid grid-cols-7 gap-1 sm:gap-2">
          {days.map((day) => (
            <DayCell key={day.offset} day={day} peak={peak} />
          ))}
        </div>
        <p className="mt-3 text-[12px] text-ink-tertiary">
          cartes prévues · point = jour révisé
        </p>
      </CardPanel>
    </Card>
  );
}

function DayCell({ day, peak }: { day: WeekDayLoad; peak: number }) {
  const today = day.offset === 0;
  const height = Math.max(day.planned > 0 ? 18 : 4, Math.round((day.planned / peak) * 44));

  return (
    <div
      className={`flex flex-col items-center rounded-lg px-0.5 py-2 sm:px-1 ${
        today ? "bg-surface-muted" : ""
      }`}
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
      <p className="mt-1 h-5 text-center text-[11px] text-ink-tertiary" aria-hidden>
        {day.reviewed ? "●" : ""}
      </p>
      <div className="mt-1 flex h-11 w-full items-end justify-center">
        <div
          className={`w-4 rounded-t-md sm:w-5 ${today ? "bg-ink" : "bg-ink/25"}`}
          style={{ height: `${height}px` }}
          title={`${day.planned} carte${day.planned > 1 ? "s" : ""}`}
        />
      </div>
      <p className="numeral mt-1 text-[13px] font-bold text-ink sm:text-[15px]">{day.planned}</p>
    </div>
  );
}

function weekday(date: Date): string {
  return date.toLocaleDateString("fr-FR", { weekday: "short" }).replace(".", "");
}
