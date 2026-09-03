import type { WeekDayLoad } from "@micabo/core";

import { Card, CardHeader, CardPanel, CardTitle } from "@/components/ui/card";
import type { Translator } from "@/lib/i18n/copy";
import { formatWeekdayShort } from "@/lib/i18n/copy";
import type { UiLocale } from "@/lib/i18n/locales";

const BAR_MAX = 52;

/**
 * La semaine glissante du tableau de bord.
 */
export function WeekStrip({
  days,
  locale,
  t,
}: {
  days: readonly WeekDayLoad[];
  locale: UiLocale;
  t: Translator;
}) {
  const peak = Math.max(1, ...days.map(dayTotal));

  return (
    <Card className="h-full min-w-0 overflow-hidden">
      <CardHeader className="pb-2">
        <CardTitle className="text-[15px] font-semibold text-ink">{t("app.home.week.title")}</CardTitle>
      </CardHeader>
      <CardPanel className="flex min-w-0 flex-1 flex-col justify-center pt-0">
        <div className="mx-auto grid w-full min-w-0 max-w-[22rem] grid-cols-7 gap-0.5 sm:gap-1.5">
          {days.map((day) => (
            <DayCell key={day.offset} day={day} peak={peak} locale={locale} t={t} />
          ))}
        </div>
        <p className="mt-3 flex flex-wrap items-center justify-center gap-x-3 gap-y-1 text-[12px] text-ink-tertiary">
          <LegendSwatch className="bg-ink" />
          {t("app.home.week.legendReviewed")}
          <LegendSwatch className="bg-ink/25" />
          {t("app.home.week.legendDue")}
        </p>
      </CardPanel>
    </Card>
  );
}

function DayCell({
  day,
  peak,
  locale,
  t,
}: {
  day: WeekDayLoad;
  peak: number;
  locale: UiLocale;
  t: Translator;
}) {
  const today = day.offset === 0;
  const reviewed = day.reviewCount;
  const due = day.planned;
  const total = reviewed + due;
  const reviewedHeight = heightFor(reviewed, peak);
  const dueHeight = heightFor(due, peak);
  const label = labelFor(day, today, locale, t);

  return (
    <div
      className={`flex min-w-0 flex-col items-center overflow-hidden rounded-lg px-0 py-2 sm:px-1 ${
        today ? "bg-surface-muted" : ""
      }`}
      aria-label={t("app.home.week.dayAria", { label, reviewed, due })}
    >
      <p
        className={`w-full truncate text-center text-[9px] font-semibold uppercase tracking-normal sm:text-[11px] sm:tracking-wide ${
          today ? "text-ink" : "text-ink-tertiary"
        }`}
      >
        <span className="sm:hidden">{today ? "·" : formatWeekdayShort(day.date, locale).slice(0, 1)}</span>
        <span className="hidden sm:inline">
          {today ? t("app.home.week.todayShort") : formatWeekdayShort(day.date, locale)}
        </span>
      </p>
      <p className="numeral mt-0.5 text-[12px] font-semibold text-ink sm:text-[14px]">
        {day.date.getDate()}
      </p>
      <div className="mt-2 flex h-[52px] w-full items-end justify-center">
        <div className="flex w-2.5 flex-col-reverse overflow-hidden rounded-t-[2px] sm:w-4">
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
      <p className="numeral mt-1 max-w-full truncate text-[12px] font-bold text-ink sm:text-[15px]">
        {total}
      </p>
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

function labelFor(day: WeekDayLoad, today: boolean, locale: UiLocale, t: Translator): string {
  if (today) return t("app.home.week.today");
  return formatWeekdayShort(day.date, locale);
}
