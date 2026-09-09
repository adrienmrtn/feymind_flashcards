"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import { startMockSession } from "@/lib/actions/mocks";
import { useI18n } from "@/lib/i18n/client";
import { localeBcp47 } from "@/lib/i18n/copy";

/**
 * **Le plan de cette épreuve, jour par jour, jusqu'au jour J.**
 *
 * La frise de l'accueil montre la période entière en un cran par jour : elle répond à « est-ce
 * que ça tient ». Elle ne répond pas à « qu'est-ce que je fais mardi », et c'est pourtant la
 * question de quelqu'un qui vient de créer un plan et veut savoir ce qu'il a signé.
 *
 * Ici chaque jour est une ligne lisible : les cartes prévues, les blancs posés, les jours de
 * pause en creux, et le jour de l'épreuve au bout. Rien n'est arrondi ni masqué - un plan qui
 * ne montre pas ses jours creux ne se vérifie pas.
 */

export interface ScheduleDay {
  /** Décalage depuis aujourd'hui. */
  offset: number;
  date: string;
  cards: number;
  minutes: number;
  capacityMinutes: number;
  /** Un examen blanc posé ce jour-là, avec son volume. */
  mock: { questionCount: number; minutes: number } | null;
  isExamDay: boolean;
}

export function ExamSchedule({
  examId,
  days,
  canRunMock,
}: {
  examId: string;
  days: ScheduleDay[];
  canRunMock: boolean;
}) {
  const { t, locale } = useI18n();
  const [expanded, setExpanded] = useState(false);

  if (days.length === 0) return null;

  const open = days.filter((day) => day.capacityMinutes > 0 && !day.isExamDay);
  const off = days.filter((day) => day.capacityMinutes === 0 && !day.isExamDay);
  const mocks = days.filter((day) => day.mock);
  const totalCards = days.reduce((sum, day) => sum + day.cards, 0);

  // Les quatorze premiers jours suffisent à comprendre le rythme ; au-delà on déplie.
  const shown = expanded ? days : days.slice(0, 14);

  return (
    <section className="rounded-group border border-border bg-card p-5" data-tour="epreuve-calendrier">
      <div className="flex flex-wrap items-baseline justify-between gap-3">
        <h2 className="text-[15px] font-semibold text-ink">{t("app.exam.schedule.title")}</h2>
        <p className="numeral text-[12.5px] text-ink-tertiary">
          {t("app.exam.schedule.summary", {
            cards: totalCards,
            days: open.length,
            off: off.length,
          })}
        </p>
      </div>

      <ul className="mt-4 divide-y divide-hairline">
        {shown.map((day) => (
          <li key={day.offset} className="flex items-center gap-3 py-2.5">
            <span
              className={`numeral w-24 shrink-0 text-[12.5px] capitalize ${
                day.offset === 0 ? "font-semibold text-ink" : "text-ink-secondary"
              }`}
            >
              {day.offset === 0
                ? t("app.plan.strip.today")
                : new Date(`${day.date}T12:00:00`).toLocaleDateString(localeBcp47(locale), {
                    weekday: "short",
                    day: "numeric",
                    month: "short",
                  })}
            </span>

            {day.isExamDay ? (
              <span className="flex-1 rounded-button bg-caution-soft px-3 py-1.5 text-[13px] font-semibold text-caution">
                {t("app.exam.schedule.examDay")}
              </span>
            ) : day.capacityMinutes === 0 ? (
              <span className="flex-1 text-[13px] text-ink-tertiary">
                {t("app.exam.schedule.off")}
              </span>
            ) : (
              <span className="flex min-w-0 flex-1 flex-wrap items-center gap-1.5">
                {day.cards > 0 ? (
                  <span className="numeral rounded-pill bg-accent-soft px-2.5 py-1 text-[12.5px] font-medium text-accent">
                    {t("app.exam.schedule.cards", {
                      cards: day.cards,
                      minutes: day.minutes,
                    })}
                  </span>
                ) : null}
                {day.mock ? (
                  <span className="numeral rounded-pill bg-caution-soft px-2.5 py-1 text-[12.5px] font-semibold text-caution">
                    {t("app.exam.schedule.mock", {
                      questions: day.mock.questionCount,
                      minutes: day.mock.minutes,
                    })}
                  </span>
                ) : null}
                {day.cards === 0 && !day.mock ? (
                  <span className="text-[13px] text-ink-tertiary">
                    {t("app.exam.schedule.free")}
                  </span>
                ) : null}
              </span>
            )}

            {day.mock && day.offset === 0 && canRunMock ? <StartMock examId={examId} /> : null}
          </li>
        ))}
      </ul>

      {days.length > 14 ? (
        <button
          type="button"
          onClick={() => setExpanded((open) => !open)}
          aria-expanded={expanded}
          className="pressable mt-3 text-[13px] font-medium text-ink-secondary underline-draw"
        >
          {expanded
            ? t("app.exam.schedule.less")
            : t("app.exam.schedule.more", { count: days.length - 14 })}
        </button>
      ) : null}

      {mocks.length > 0 ? (
        <p className="mt-4 text-[12.5px] leading-relaxed text-ink-tertiary">
          {t("app.exam.schedule.mockHint", { count: mocks.length })}
        </p>
      ) : null}
    </section>
  );
}

function StartMock({ examId }: { examId: string }) {
  const { t } = useI18n();
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  return (
    <Button
      size="sm"
      disabled={pending}
      onClick={() =>
        startTransition(async () => {
          const result = await startMockSession(examId);
          if (result.status === "ok" && result.sessionId) {
            router.push(`/app/plan/blanc/${result.sessionId}` as never);
          }
        })
      }
    >
      {pending ? t("app.exams.wait") : t("app.mock.start")}
    </Button>
  );
}
