import type { WeekDayLoad } from "@micabo/core";

/**
 * La semaine glissante du tableau de bord.
 *
 * Sept colonnes, trois jours derrière et trois devant. Le chiffre est le
 * nombre de cartes encore dues ce jour-là - en direct, pas une moyenne.
 * La flamme dit qu'on a déjà ouvert une session ce jour.
 */
export function WeekStrip({ days }: { days: readonly WeekDayLoad[] }) {
  const peak = Math.max(1, ...days.map((day) => day.planned));

  return (
    <section className="paper hover-tile mt-8 rounded-group bg-surface px-4 py-5 sm:px-5">
      <p className="eyebrow text-ink-tertiary">📅 Semaine</p>
      <div className="mt-4 grid grid-cols-7 gap-1 sm:gap-2">
        {days.map((day) => (
          <DayCell key={day.offset} day={day} peak={peak} />
        ))}
      </div>
      <p className="mt-3 text-center text-[12px] text-ink-tertiary">
        cartes prévues · 🔥 jour révisé
      </p>
    </section>
  );
}

function DayCell({ day, peak }: { day: WeekDayLoad; peak: number }) {
  const today = day.offset === 0;
  const height = Math.max(day.planned > 0 ? 18 : 4, Math.round((day.planned / peak) * 44));

  return (
    <div
      className={`flex flex-col items-center rounded-tile px-0.5 py-2 sm:px-1 ${
        today ? "bg-accent-soft" : ""
      }`}
    >
      <p
        className={`text-[10px] font-semibold uppercase tracking-wide sm:text-[11px] ${
          today ? "text-accent" : "text-ink-tertiary"
        }`}
      >
        {today ? "auj." : weekday(day.date)}
      </p>
      <p
        className={`numeral mt-0.5 text-[13px] font-semibold sm:text-[14px] ${
          today ? "text-accent" : "text-ink"
        }`}
      >
        {day.date.getDate()}
      </p>
      <p className="emoji mt-1 h-5 text-[14px]" aria-hidden>
        {day.reviewed ? "🔥" : ""}
      </p>
      <div className="mt-1 flex h-11 w-full items-end justify-center">
        <div
          className={`w-4 rounded-t-md sm:w-5 ${today ? "bg-accent" : "bg-ink/25"}`}
          style={{ height: `${height}px` }}
          title={`${day.planned} carte${day.planned > 1 ? "s" : ""}`}
        />
      </div>
      <p
        className={`numeral mt-1 text-[13px] font-bold sm:text-[15px] ${
          today ? "text-accent" : "text-ink"
        }`}
      >
        {day.planned}
      </p>
    </div>
  );
}

function weekday(date: Date): string {
  return date.toLocaleDateString("fr-FR", { weekday: "short" }).replace(".", "");
}
