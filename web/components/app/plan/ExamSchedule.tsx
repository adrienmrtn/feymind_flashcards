"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";

import type { AgendaKind, AgendaStatus } from "@micabo/core";

import { StartMock } from "@/components/app/plan/StartMock";
import { Button } from "@/components/ui/button";
import { moveMeasure } from "@/lib/actions/exam-plan";
import { useI18n } from "@/lib/i18n/client";
import { localeBcp47 } from "@/lib/i18n/copy";

/** Le rendez-vous de mesure qui tombe ce jour-là. Au plus un : l'agenda les écarte. */
export interface ScheduleMeasure {
  kind: AgendaKind;
  /** Son rang dans sa série, compté depuis l'épreuve. C'est ce qu'un déplacement désigne. */
  slot: number;
  status: AgendaStatus;
  questionCount: number;
  minutes: number;
  /** La date qu'aurait donnée la dérivation, quand ce rendez-vous a été déplacé. */
  plannedDate: string | null;
}

export interface ScheduleDay {
  offset: number;
  date: string;
  cards: number;
  minutes: number;
  measure: ScheduleMeasure | null;
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
 *
 * **Une case qui porte un rendez-vous se touche.** Elle ouvre de quoi le déplacer : un examen
 * blanc tombe un jour où l'on travaille, un test de parcours un jour de match, et un plan
 * qu'on ne peut pas ajuster est un plan qu'on abandonne. Ce qui se déplace est le
 * rendez-vous, pas la mesure : c'est son rang qui part au serveur, jamais sa date.
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
  const [picked, setPicked] = useState<ScheduleDay | null>(null);
  if (days.length === 0) return null;

  const working = days.filter((day) => !day.isExamDay && (day.cards > 0 || day.measure));
  const free = days.filter((day) => !day.isExamDay && day.cards === 0 && !day.measure);
  const mocks = days.filter((day) => day.measure?.kind === "mock");
  const parcours = days.filter((day) => day.measure?.kind === "parcours");
  const totalCards = days.reduce((sum, day) => sum + day.cards, 0);
  // La barre parle du **nombre de cartes**, comme le chiffre au-dessus d'elle. Elle mesurait
  // des minutes tandis que la case en affichait aussi : deux échelles pour une seule case.
  const max = Math.max(1, ...days.map((day) => day.cards));
  const shown = expanded ? days : days.slice(0, 21);
  const today = days.find((day) => day.offset === 0);
  const todayMeasure = today?.measure?.status === "upcoming" ? today.measure : null;

  const weeks: ScheduleDay[][] = [];
  for (const day of shown) {
    const index = Math.floor(day.offset / 7);
    (weeks[index] ??= []).push(day);
  }

  /** Ce que porte la case, en une ligne : c'est l'infobulle et la moitié de l'étiquette. */
  function measureLine(measure: ScheduleMeasure): string {
    return t(measure.kind === "mock" ? "app.exam.schedule.mock" : "app.exam.schedule.parcours", {
      questions: measure.questionCount,
      minutes: measure.minutes,
    });
  }

  function kindLabel(kind: AgendaKind): string {
    return t(kind === "mock" ? "app.mock.blockTitle" : "app.parcours.blockTitle");
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
        {/*
          Un parcours se lance même quand la copie de vingt questions n'a pas de quoi se
          composer : il en demande dix, et il n'est pas tiré des cartes mais du programme.
        */}
        {todayMeasure && (todayMeasure.kind === "parcours" || canRunMock) ? (
          <StartMock examId={examId} kind={todayMeasure.kind} />
        ) : null}
      </div>

      <ol className="mt-4 space-y-2">
        {weeks.map((week, weekIndex) => (
          <li key={weekIndex} className="grid grid-cols-7 gap-1.5">
            {week.map((day) => {
              const date = new Date(`${day.date}T12:00:00`);
              const label = date.toLocaleDateString(bcp, { weekday: "short" }).replace(".", "");
              const measure = day.measure;
              const line = measure ? measureLine(measure) : "";
              const title = day.isExamDay
                ? t("app.exam.schedule.examDay")
                : day.isOff && day.cards === 0 && !measure
                  ? t("app.exam.schedule.off")
                  : day.cards === 0 && !measure
                    ? t("app.exam.schedule.free")
                    : day.cards === 0
                      ? line
                      : `${t("app.exam.schedule.cards", { cards: day.cards, minutes: day.minutes })}${line ? ` · ${line}` : ""}`;
              const fill = Math.min(1, day.cards / max);
              const movable = Boolean(measure) && measure?.status !== "done" && !day.isExamDay;

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

                    **Trois teintes, et le jour J n'en prend aucune.** Le blanc est bleu, le
                    parcours ambre - les mêmes que le calendrier de l'app, pour qu'une couleur
                    veuille dire la même chose sur les deux écrans. Le jour de l'épreuve tenait
                    l'ambre ; il passe donc à l'encre, qui le distingue mieux de toute façon :
                    c'est le seul jour où l'on ne s'entraîne pas.
                  */
                  className={`relative flex h-16 flex-col justify-between overflow-hidden rounded-[10px] border p-1.5 text-[10.5px] ${
                    day.isExamDay
                      ? "border-ink/40 bg-ink/[0.07]"
                      : measure?.status === "done"
                        ? "border-positive/40 bg-positive-soft"
                        : measure?.kind === "mock"
                          ? "border-accent/50 bg-accent-soft"
                          : measure
                            ? "border-caution/45 bg-caution-soft"
                            : day.offset === 0
                              ? "border-ink/40 bg-surface"
                              : day.cards === 0
                                ? "border-transparent bg-surface-muted/50"
                                : "border-hairline bg-surface"
                  } ${picked?.offset === day.offset ? "ring-2 ring-ink/30" : ""}`}
                >
                  <span
                    className={`flex items-baseline justify-between ${
                      measure?.status === "done"
                        ? "font-semibold text-positive"
                        : measure?.kind === "mock"
                          ? "font-semibold text-accent"
                          : measure
                            ? "font-semibold text-caution"
                            : day.offset === 0
                              ? "font-semibold text-ink"
                              : "text-ink-tertiary"
                    }`}
                  >
                    <span className="uppercase tracking-wide">{label}</span>
                    <span className="numeral">{date.getDate()}</span>
                  </span>
                  {day.isExamDay ? (
                    <span className="text-[10px] font-semibold text-ink">
                      {t("app.exam.schedule.examShort")}
                    </span>
                  ) : measure ? (
                    <span
                      className={`truncate text-[9.5px] font-semibold uppercase tracking-wide ${
                        measure.status === "done"
                          ? "text-positive"
                          : measure.kind === "mock"
                            ? "text-accent"
                            : "text-caution"
                      }`}
                    >
                      {t(
                        measure.kind === "mock"
                          ? "app.exam.schedule.mockShort"
                          : "app.exam.schedule.parcoursShort",
                      )}
                    </span>
                  ) : day.isOff && day.cards === 0 ? (
                    <span aria-hidden className="emoji text-[11px] leading-none">
                      💤
                    </span>
                  ) : day.cards === 0 ? (
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
                          backgroundColor: measure ? "var(--chart-fragile)" : "var(--chart-work)",
                        }}
                      />
                    </span>
                  ) : null}

                  {/*
                    Le bouton couvre la case au lieu de l'être : la case est déjà une pile de
                    trois éléments et d'un filet, et les mettre dans un <button> ferait
                    hériter chacun de ses styles de contrôle.
                  */}
                  {movable && measure ? (
                    <button
                      type="button"
                      onClick={() => setPicked(picked?.offset === day.offset ? null : day)}
                      className="pressable absolute inset-0 cursor-pointer rounded-[10px]"
                      aria-label={`${kindLabel(measure.kind)} · ${date.toLocaleDateString(bcp, { day: "numeric", month: "long" })} · ${t("app.agenda.moveTitle")}`}
                    />
                  ) : null}
                </div>
              );
            })}
          </li>
        ))}
      </ol>

      {picked?.measure ? (
        <MoveMeasure
          examId={examId}
          days={days}
          day={picked}
          measure={picked.measure}
          title={kindLabel(picked.measure.kind)}
          line={measureLine(picked.measure)}
          onDone={() => setPicked(null)}
        />
      ) : null}

      <div className="mt-3 flex flex-wrap items-center justify-between gap-3 text-[12px] text-ink-tertiary">
        <span>
          {mocks.length > 0 ? t("app.exam.schedule.mockHint", { count: mocks.length }) : ""}
          {parcours.length > 0 ? (
            <>
              {mocks.length > 0 ? " " : ""}
              {t("app.exam.schedule.parcoursHint", { count: parcours.length })}
            </>
          ) : null}
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

/**
 * **Ce qu'est ce rendez-vous, et quand on le veut.**
 *
 * Elle ne propose pas de lancer le test : le plan d'une épreuve dit ce qui est prévu, pas où
 * l'on travaille. On passe la mesure depuis le bandeau du jour, quand le jour est venu.
 *
 * Le sélecteur est borné à aujourd'hui et à la veille de l'épreuve, et le serveur tient les
 * mêmes bornes : un rendez-vous posé hier naîtrait manqué, et un posé le jour J révélerait une
 * lacune qu'il n'y a plus le temps de corriger.
 */
function MoveMeasure({
  examId,
  days,
  day,
  measure,
  title,
  line,
  onDone,
}: {
  examId: string;
  /** Les jours du plan, dont les bornes sortent : ce sont des dates du serveur. */
  days: ScheduleDay[];
  day: ScheduleDay;
  measure: ScheduleMeasure;
  title: string;
  line: string;
  onDone: () => void;
}) {
  const { t, locale } = useI18n();
  const bcp = localeBcp47(locale);
  const router = useRouter();
  const [chosen, setChosen] = useState(day.date);
  const [pending, startTransition] = useTransition();
  const [failed, setFailed] = useState<string | null>(null);

  /**
   * Les bornes viennent du plan, **pas de l'horloge du navigateur**.
   *
   * Le plan est daté par le serveur ; recalculer « aujourd'hui » ici ferait diverger les deux
   * d'un jour entier pour qui ouvre le site à une heure du matin, et le sélecteur refuserait
   * la case que la grille vient de proposer.
   */
  const first = days[0]?.date ?? day.date;
  // La veille de l'épreuve : le jour J appartient à l'épreuve, pas à sa préparation.
  const last = [...days].reverse().find((candidate) => !candidate.isExamDay)?.date ?? first;

  function submit(date: string | null) {
    setFailed(null);
    startTransition(async () => {
      const result = await moveMeasure({ examId, kind: measure.kind, slot: measure.slot, date });
      if (result.status === "ok") {
        router.refresh();
        onDone();
        return;
      }
      setFailed(result.message ?? t("app.mock.failed"));
    });
  }

  const readable = (iso: string) =>
    new Date(`${iso}T12:00:00`).toLocaleDateString(bcp, {
      weekday: "long",
      day: "numeric",
      month: "long",
    });

  return (
    <div className="mt-4 rounded-group border border-hairline bg-surface-muted/60 p-4">
      <p className="text-[13.5px] font-semibold text-ink">{title}</p>
      <p className="numeral mt-0.5 text-[12.5px] text-ink-secondary">
        {readable(day.date)} · {line}
      </p>
      {measure.plannedDate ? (
        <p className="mt-0.5 text-[12px] text-ink-tertiary">
          {t("app.agenda.movedFrom", { date: readable(measure.plannedDate) })}
        </p>
      ) : null}

      <div className="mt-3 flex flex-wrap items-center gap-2">
        <label className="sr-only" htmlFor="move-measure-date">
          {t("app.agenda.moveTitle")}
        </label>
        <input
          id="move-measure-date"
          type="date"
          value={chosen}
          min={first}
          max={last}
          onChange={(event) => setChosen(event.target.value)}
          className="numeral h-9 rounded-[10px] border border-hairline bg-surface px-2.5 text-[13px] text-ink"
        />
        <Button size="sm" disabled={pending || chosen === day.date} onClick={() => submit(chosen)}>
          {pending ? t("app.exams.wait") : t("app.agenda.move")}
        </Button>
        {measure.plannedDate ? (
          <Button size="sm" variant="outline" disabled={pending} onClick={() => submit(null)}>
            {t("app.agenda.reset")}
          </Button>
        ) : null}
        <Button size="sm" variant="ghost" disabled={pending} onClick={onDone}>
          {t("app.common.cancel")}
        </Button>
      </div>

      {failed ? (
        <p className="mt-2 text-[12.5px] text-negative" role="alert">
          {failed}
        </p>
      ) : null}
    </div>
  );
}
