"use client";

import { useState } from "react";

import { StartMock } from "@/components/app/plan/StartMock";
import { useI18n } from "@/lib/i18n/client";
import { localeBcp47 } from "@/lib/i18n/copy";

export interface ScheduleDay {
  offset: number;
  date: string;
  cards: number;
  minutes: number;
  mock: { questionCount: number; minutes: number } | null;
  isExamDay: boolean;
  /** Un jour posé off au moment du plan : vide par choix, pas faute de travail. */
  isOff: boolean;
}

/**
 * Le plan de cette épreuve, jour par jour, **en une rangée par semaine.**
 *
 * L'ancienne liste alignait quatorze lignes « rien de prévu » : on la faisait défiler sans
 * rien lire. Ici chaque jour est une case, la hauteur du remplissage dit la charge, et le
 * détail vient au survol. Une semaine tient sur une ligne, l'épreuve se voit tout de suite.
 */
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
  const bcp = localeBcp47(locale);
  const [expanded, setExpanded] = useState(false);
  if (days.length === 0) return null;

  const working = days.filter((day) => !day.isExamDay && (day.cards > 0 || day.mock));
  const free = days.filter((day) => !day.isExamDay && day.cards === 0 && !day.mock);
  const mocks = days.filter((day) => day.mock);
  const totalCards = days.reduce((sum, day) => sum + day.cards, 0);
  // La barre parle du **nombre de cartes**, comme le chiffre au-dessus d'elle. Elle mesurait
  // des minutes tandis que la case en affichait aussi : deux échelles pour une seule case.
  const max = Math.max(1, ...days.map((day) => day.cards));
  const shown = expanded ? days : days.slice(0, 21);
  const todayMock = days.find((day) => day.offset === 0 && day.mock);

  const weeks: ScheduleDay[][] = [];
  for (const day of shown) {
    const index = Math.floor(day.offset / 7);
    (weeks[index] ??= []).push(day);
  }

  return (
    <section className="panel p-5" data-tour="epreuve-calendrier">
      <div className="flex flex-wrap items-baseline justify-between gap-3">
        <div>
          <h2 className="section-title">{t("app.exam.schedule.title")}</h2>
          <p className="section-lead numeral">
            {t("app.exam.schedule.summary", {
              cards: totalCards,
              days: working.length,
              free: free.length,
            })}
          </p>
        </div>
        {todayMock && canRunMock ? <StartMock examId={examId} /> : null}
      </div>

      <ol className="mt-4 space-y-2">
        {weeks.map((week, weekIndex) => (
          <li key={weekIndex} className="grid grid-cols-7 gap-1.5">
            {week.map((day) => {
              const date = new Date(`${day.date}T12:00:00`);
              const label = date.toLocaleDateString(bcp, { weekday: "short" }).replace(".", "");
              const title = day.isExamDay
                ? t("app.exam.schedule.examDay")
                : day.isOff && day.cards === 0 && !day.mock
                  ? t("app.exam.schedule.off")
                  : day.cards === 0 && !day.mock
                    ? t("app.exam.schedule.free")
                  : `${t("app.exam.schedule.cards", { cards: day.cards, minutes: day.minutes })}${day.mock ? ` · ${t("app.exam.schedule.mock", { questions: day.mock.questionCount, minutes: day.mock.minutes })}` : ""}`;
              const fill = Math.min(1, day.cards / max);
              return (
                <div
                  key={day.offset}
                  title={`${date.toLocaleDateString(bcp, { weekday: "long", day: "numeric", month: "long" })} · ${title}`}
                  /*
                    Un examen blanc se voyait à une pastille de deux pixels dans un coin, la
                    même que le jour de l'épreuve. Or ce n'est pas une nuance de charge :
                    c'est le seul jour de la période où l'on est mesuré, et il faut le voir
                    venir de loin pour ne pas le découvrir le matin même. Il prend donc la
                    couleur du produit et écrit son nom.
                  */
                  className={`relative flex h-16 flex-col justify-between overflow-hidden rounded-[10px] border p-1.5 text-[10.5px] ${
                    day.isExamDay
                      ? "border-caution/40 bg-caution-soft"
                      : day.mock
                        ? "border-accent/50 bg-accent-soft"
                        : day.offset === 0
                          ? "border-ink/40 bg-surface"
                          : day.cards === 0 && !day.mock
                            ? "border-transparent bg-surface-muted/50"
                            : "border-hairline bg-surface"
                  }`}
                >
                  <span
                    className={`flex items-baseline justify-between ${
                      day.mock ? "font-semibold text-accent" : day.offset === 0 ? "font-semibold text-ink" : "text-ink-tertiary"
                    }`}
                  >
                    <span className="uppercase tracking-wide">{label}</span>
                    <span className="numeral">{date.getDate()}</span>
                  </span>
                  {day.isExamDay ? (
                    <span className="text-[10px] font-semibold text-caution">
                      {t("app.exam.schedule.examShort")}
                    </span>
                  ) : day.mock ? (
                    <span className="truncate text-[9.5px] font-semibold uppercase tracking-wide text-accent">
                      {t("app.exam.schedule.mockShort")}
                    </span>
                  ) : day.isOff && day.cards === 0 && !day.mock ? (
                    <span aria-hidden className="emoji text-[11px] leading-none">
                      💤
                    </span>
                  ) : day.cards === 0 && !day.mock ? (
                    <span className="text-[10px] text-ink-tertiary">
                      {t("app.exam.schedule.freeShort")}
                    </span>
                  ) : (
                    /*
                      **Un nombre de cartes, pas un nombre de minutes.**

                      La case annonçait « 1 min » vingt fois de suite, à côté d'un trait de
                      six pixels de haut censé porter la charge du jour. Deux défauts d'un
                      coup : la minute est ce que le plan estime le plus mal - elle dépend de
                      la vitesse de celui qui révise - et une barre verticale de la hauteur
                      d'une lettre ne se compare pas d'une case à l'autre.

                      Le chiffre qui compte est donc écrit en grand, et la charge relative
                      passe dans un filet posé au bas de la case, sur toute sa largeur : sept
                      cases côte à côte se lisent alors comme un profil de semaine.
                    */
                    <span className="flex items-baseline gap-1">
                      <span className="numeral text-[15px] font-semibold leading-none text-ink">
                        {day.cards}
                      </span>
                      <span className="truncate text-[9.5px] uppercase tracking-wide text-ink-tertiary">
                        {t("app.exam.schedule.cardsShort")}
                      </span>
                    </span>
                  )}

                  {day.cards > 0 && !day.isExamDay ? (
                    <span
                      aria-hidden
                      className="absolute inset-x-0 bottom-0 h-[3px] bg-surface-sunken"
                    >
                      <span
                        className="block h-full rounded-r-full"
                        style={{
                          width: `${Math.max(14, fill * 100)}%`,
                          backgroundColor: day.mock ? "var(--chart-fragile)" : "var(--chart-work)",
                        }}
                      />
                    </span>
                  ) : null}
                </div>
              );
            })}
          </li>
        ))}
      </ol>

      <div className="mt-3 flex flex-wrap items-center justify-between gap-3 text-[12px] text-ink-tertiary">
        <span>
          {mocks.length > 0 ? t("app.exam.schedule.mockHint", { count: mocks.length }) : ""}
        </span>
        {days.length > 21 ? (
          <button
            type="button"
            onClick={() => setExpanded((open) => !open)}
            aria-expanded={expanded}
            className="pressable underline-draw font-medium text-ink-secondary"
          >
            {expanded ? t("app.exam.schedule.less") : t("app.exam.schedule.more", { count: days.length - 21 })}
          </button>
        ) : null}
      </div>
    </section>
  );
}
