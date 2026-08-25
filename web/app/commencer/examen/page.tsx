"use client";

import { useMemo, useState } from "react";
import Link from "next/link";

import { addDays, dayDifference, startOfDay } from "@micabo/core";

import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";
import { WordByWord } from "@/components/onboarding/WordByWord";
import { useOnboarding } from "@/lib/onboarding/store";

/**
 * La date du prochain examen.
 *
 * C'est le seul écran du parcours qui **écrit hors de `profiles`** : il crée une vraie ligne dans
 * `exams`, ce qui rend tenable la promesse qu'il affiche. Et c'est aussi une meilleure question que
 * « combien de minutes par jour » — d'où l'absence de cet écran-là.
 *
 * Le calendrier est **posé directement**, ouvert sur le mois en cours, et il ne recule jamais avant
 * aujourd'hui : une date d'examen dans le passé n'est pas une réponse, c'est une faute de frappe
 * qu'on laisserait passer.
 *
 * Le raccourci « Je sais pas encore » est au-dessus, pas en dessous : quelqu'un qui n'a pas de date
 * doit pouvoir le dire **avant** d'avoir cherché dans trois mois.
 */
export default function ExamStep() {
  const { answers, set, ready } = useOnboarding();

  const today = useMemo(() => startOfDay(new Date()), []);
  const [month, setMonth] = useState(() => new Date(today.getFullYear(), today.getMonth(), 1));
  const [confirmed, setConfirmed] = useState(false);

  const chosen = answers.examDate ? startOfDay(new Date(`${answers.examDate}T12:00:00`)) : null;
  const daysLeft = chosen ? dayDifference(today, chosen) : null;

  function choose(date: Date) {
    setConfirmed(false);
    set({ examDate: toISODate(date) });
  }

  if (confirmed && daysLeft !== null) {
    return (
      <Scaffold
        eyebrow="Ton examen"
        title={<>C&apos;est noté.</>}
        footer={<ContinueButton label="Voir comment ça marche" enabled href="/commencer/demo" />}
      >
        <div className="text-center">
          <p className="numeral text-[72px] font-bold leading-none text-accent">
            {Math.max(0, daysLeft)}
          </p>
          <p className="mt-2 text-[15px] text-ink-tertiary">
            jour{daysLeft > 1 ? "s" : ""} avant le jour J
          </p>
          <WordByWord
            text="On va bien s'organiser."
            className="mt-8 text-[22px] leading-snug"
          />
        </div>
      </Scaffold>
    );
  }

  return (
    <Scaffold
      eyebrow="Ton examen"
      title="C'est quand, ton prochain examen ?"
      subtitle="Micabo te créera un parcours adapté à ton examen, pour que tu arrives plus prêt que jamais."
      footer={
        <ContinueButton
          label="Réussir cet examen"
          enabled={Boolean(chosen) && ready}
          shiny
          onPress={() => setConfirmed(true)}
        />
      }
    >
      {/* **L'échappatoire est posée au-dessus du calendrier, et pas dans le coin du sur-titre.**
          Elle y était, en gris de treize points, et une relecture attentive de l'écran ne l'a pas
          trouvée — donc un étudiant non plus. Ce n'est pas une échappatoire de confort comme celle
          de l'école : pour tous ceux qui n'ont pas encore de date, « je sais pas encore » *est* la
          réponse. Une réponse qu'on ne trouve pas se paye en dates choisies au hasard, c'est-à-dire
          en fausses données. */}
      <Link
        href="/commencer/demo"
        className="pressable mb-4 flex items-center justify-center gap-2 rounded-button bg-surface-muted py-3 text-[14.5px] font-medium text-ink-secondary"
      >
        Je sais pas encore
        <svg aria-hidden viewBox="0 0 20 20" className="h-4 w-4">
          <path
            d="M8 4l6 6-6 6"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.8"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      </Link>

      <div className="paper rounded-group bg-surface p-4">
        <div className="flex items-center justify-between">
          <button
            type="button"
            aria-label="Mois précédent"
            disabled={!canGoBack(month, today)}
            onClick={() => setMonth(shiftMonth(month, -1))}
            className="pressable flex h-9 w-9 items-center justify-center rounded-full text-ink-secondary disabled:opacity-30"
          >
            <Chevron direction="left" />
          </button>
          <p className="text-[15px] font-semibold text-ink first-letter:uppercase">
            {monthLabel(month)}
          </p>
          <button
            type="button"
            aria-label="Mois suivant"
            onClick={() => setMonth(shiftMonth(month, 1))}
            className="pressable flex h-9 w-9 items-center justify-center rounded-full text-ink-secondary"
          >
            <Chevron direction="right" />
          </button>
        </div>

        <div className="mt-4 grid grid-cols-7 gap-1 text-center">
          {["L", "M", "M", "J", "V", "S", "D"].map((initial, index) => (
            <span key={index} className="pb-1 text-[11px] font-medium text-ink-tertiary">
              {initial}
            </span>
          ))}

          {cellsFor(month).map((date, index) => {
            if (!date) return <span key={`empty-${index}`} />;

            const past = date.getTime() < today.getTime();
            const isChosen = chosen?.getTime() === date.getTime();
            const isToday = date.getTime() === today.getTime();

            return (
              <button
                key={date.toISOString()}
                type="button"
                disabled={past}
                onClick={() => choose(date)}
                aria-pressed={isChosen}
                className={`numeral aspect-square rounded-[10px] text-[14px] transition-colors duration-hover ${
                  isChosen
                    ? "bg-accent font-bold text-on-ink"
                    : past
                      ? "text-ink-tertiary/40"
                      : isToday
                        ? "bg-surface-muted font-semibold text-ink"
                        : "text-ink hover:bg-surface-muted"
                }`}
              >
                {date.getDate()}
              </button>
            );
          })}
        </div>
      </div>

      {daysLeft !== null ? (
        <p className="mt-5 text-center text-[14px] text-ink-secondary">
          {fullDate(chosen!)} · dans{" "}
          <span className="numeral font-bold text-ink">{Math.max(0, daysLeft)}</span> jour
          {daysLeft > 1 ? "s" : ""}
        </p>
      ) : (
        <p className="mt-5 text-center text-[13px] text-ink-tertiary">
          Touche une date. Tu pourras la changer plus tard.
        </p>
      )}
    </Scaffold>
  );
}

// MARK: - Le calendrier, à la main

/** Lundi en premier, comme `MicaboCalendar` côté iOS. */
function cellsFor(month: Date): (Date | null)[] {
  const first = new Date(month.getFullYear(), month.getMonth(), 1);
  const leading = (first.getDay() + 6) % 7;
  const days = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();

  return [
    ...Array.from({ length: leading }, () => null),
    ...Array.from({ length: days }, (_, index) =>
      startOfDay(new Date(month.getFullYear(), month.getMonth(), index + 1)),
    ),
  ];
}

function shiftMonth(month: Date, delta: number): Date {
  return new Date(month.getFullYear(), month.getMonth() + delta, 1);
}

/** On ne revient pas avant le mois en cours : il n'y a rien à y choisir. */
function canGoBack(month: Date, today: Date): boolean {
  return month.getFullYear() > today.getFullYear() || month.getMonth() > today.getMonth();
}

function monthLabel(month: Date): string {
  return month.toLocaleDateString("fr-FR", { month: "long", year: "numeric" });
}

function fullDate(date: Date): string {
  return date.toLocaleDateString("fr-FR", { weekday: "long", day: "numeric", month: "long" });
}

function toISODate(date: Date): string {
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${date.getFullYear()}-${month}-${day}`;
}

function Chevron({ direction }: { direction: "left" | "right" }) {
  return (
    <svg aria-hidden viewBox="0 0 20 20" className="h-4 w-4">
      <path
        d={direction === "left" ? "M12 4l-6 6 6 6" : "M8 4l6 6-6 6"}
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
