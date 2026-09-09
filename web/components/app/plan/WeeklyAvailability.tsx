"use client";

import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";

import {
  clampMinutes,
  dailyMinutesLabel,
  weeklyTotal,
  type WeeklyMinutes,
} from "@micabo/core";

import { Button } from "@/components/ui/button";
import { Slider } from "@/components/ui/slider";
import { saveWeeklyMinutes, setDayAvailability } from "@/lib/actions/availability";
import { useI18n } from "@/lib/i18n/client";
import { localeBcp47 } from "@/lib/i18n/copy";

/**
 * **Mes semaines** : sept curseurs, et les jours qu'on retire.
 *
 * C'est le réglage qui rend le plan honnête, et c'est pour ça qu'il n'est pas dans les
 * réglages : il appartient au Plan, il se remplit une fois par semestre, et il doit se
 * remplir en deux minutes. Chaque mouvement de curseur réécrit le total, parce que c'est le
 * total que l'étudiant arbitre, pas les sept valeurs prises une à une.
 *
 * Les exceptions sont **datées et réversibles** : une semaine de stage se pose ici, elle ne
 * déforme pas la semaine type.
 */

const STEPS = [0, 10, 15, 20, 30, 45, 60, 90, 120, 150, 180, 240] as const;

export interface ExceptionRow {
  day: string;
  minutes: number;
}

export function WeeklyAvailability({
  initial,
  exceptions,
}: {
  initial: WeeklyMinutes;
  exceptions: ExceptionRow[];
}) {
  const { t, locale } = useI18n();
  const router = useRouter();
  const [week, setWeek] = useState<number[]>([...initial]);
  const [pending, startTransition] = useTransition();
  const [saved, setSaved] = useState(false);
  const [failed, setFailed] = useState(false);
  const [newDay, setNewDay] = useState("");

  const names = useMemo(() => weekdayNames(locale), [locale]);
  const total = weeklyTotal(week as unknown as WeeklyMinutes);
  const openDays = week.filter((minutes) => minutes > 0).length;
  const dirty = week.some((minutes, index) => minutes !== initial[index]);

  function setDay(index: number, minutes: number) {
    setSaved(false);
    setWeek((current) =>
      current.map((value, position) => (position === index ? clampMinutes(minutes) : value)),
    );
  }

  function save() {
    setFailed(false);
    startTransition(async () => {
      const result = await saveWeeklyMinutes(week);
      if (result.status === "error") setFailed(true);
      else {
        setSaved(true);
        router.refresh();
      }
    });
  }

  function toggleException(day: string, minutes: number | null) {
    setFailed(false);
    startTransition(async () => {
      const result = await setDayAvailability(day, minutes);
      if (result.status === "error") setFailed(true);
      else {
        setNewDay("");
        router.refresh();
      }
    });
  }

  return (
    <div className="space-y-5">
      <section className="rounded-group border border-border bg-card p-5">
        <div className="flex flex-wrap items-baseline justify-between gap-3">
          <h2 className="text-[15px] font-semibold text-ink">{t("app.plan.weekly.title")}</h2>
          <p className="numeral text-[13px] text-ink-secondary">
            {t("app.plan.weekly.total", {
              total: dailyMinutesLabel(total),
              days: openDays,
            })}
          </p>
        </div>

        <ul className="mt-4 divide-y divide-hairline">
          {week.map((minutes, index) => (
            <li key={index} className="flex items-center gap-4 py-3">
              <span className="w-24 shrink-0 text-[14px] font-medium capitalize text-ink">
                {names[index]}
              </span>
              <Slider
                className="min-w-0 flex-1"
                min={0}
                max={STEPS.length - 1}
                step={1}
                value={stepIndexOf(minutes)}
                onValueChange={(value) => setDay(index, STEPS[Number(value)] ?? 0)}
                aria-label={names[index]}
              />
              <span
                className={`numeral w-16 shrink-0 text-right text-[13px] ${
                  minutes === 0 ? "text-ink-tertiary" : "text-ink"
                }`}
              >
                {minutes === 0 ? t("app.plan.weekly.off") : dailyMinutesLabel(minutes)}
              </span>
            </li>
          ))}
        </ul>

        <div className="mt-4 flex flex-wrap items-center gap-3">
          <Button onClick={save} disabled={pending || !dirty}>
            {pending ? t("app.plan.weekly.saving") : t("app.common.save")}
          </Button>
          {saved && !dirty ? (
            <span className="text-[13px] text-positive">{t("app.plan.weekly.saved")}</span>
          ) : null}
        </div>

        <p className="mt-3 text-[12.5px] leading-relaxed text-ink-tertiary">
          {t("app.plan.weekly.hint")}
        </p>
      </section>

      <section className="rounded-group border border-border bg-card p-5">
        <h2 className="text-[15px] font-semibold text-ink">
          {t("app.plan.exceptions.title")}
        </h2>
        <p className="mt-1 text-[13px] text-ink-secondary">
          {t("app.plan.exceptions.lead")}
        </p>

        {exceptions.length > 0 ? (
          <ul className="mt-4 divide-y divide-hairline">
            {exceptions.map((exception) => (
              <li key={exception.day} className="flex items-center justify-between gap-3 py-3">
                <span className="min-w-0">
                  <span className="block truncate text-[14.5px] text-ink">
                    {longDate(exception.day, locale)}
                  </span>
                  <span className="numeral mt-0.5 block text-[12.5px] text-ink-tertiary">
                    {exception.minutes === 0
                      ? t("app.plan.weekly.off")
                      : dailyMinutesLabel(exception.minutes)}
                  </span>
                </span>
                <Button
                  size="sm"
                  variant="outline"
                  disabled={pending}
                  onClick={() => toggleException(exception.day, null)}
                >
                  {t("app.plan.exceptions.remove")}
                </Button>
              </li>
            ))}
          </ul>
        ) : (
          <p className="mt-4 text-[13.5px] text-ink-tertiary">
            {t("app.plan.exceptions.none")}
          </p>
        )}

        <div className="mt-4 flex flex-wrap items-center gap-2">
          <input
            type="date"
            value={newDay}
            onChange={(event) => setNewDay(event.target.value)}
            className="h-10 rounded-button border border-border bg-surface px-3 text-[14px] text-ink"
            aria-label={t("app.plan.exceptions.pick")}
          />
          <Button
            size="sm"
            disabled={pending || !newDay}
            onClick={() => toggleException(newDay, 0)}
          >
            {t("app.plan.exceptions.add")}
          </Button>
        </div>
      </section>

      {failed ? (
        <p className="text-[13px] text-negative" role="alert">
          {t("app.plan.verdict.failed")}
        </p>
      ) : null}
    </div>
  );
}

/** Le cran le plus proche : un curseur qui glisse sur des paliers, pas sur les minutes. */
function stepIndexOf(minutes: number): number {
  let best = 0;
  STEPS.forEach((step, index) => {
    if (Math.abs(step - minutes) < Math.abs((STEPS[best] ?? 0) - minutes)) best = index;
  });
  return best;
}

/** Les sept jours dans l'ordre du tableau : lundi en premier, partout. */
function weekdayNames(locale: string): string[] {
  const monday = new Date(2024, 0, 1);
  return Array.from({ length: 7 }, (_, index) => {
    const day = new Date(monday.getTime());
    day.setDate(day.getDate() + index);
    return day.toLocaleDateString(localeBcp47(locale as never), { weekday: "long" });
  });
}

function longDate(iso: string, locale: string): string {
  return new Date(`${iso}T12:00:00`).toLocaleDateString(localeBcp47(locale as never), {
    weekday: "long",
    day: "numeric",
    month: "long",
  });
}
