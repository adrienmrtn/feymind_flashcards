"use client";

import { useEffect, useState } from "react";

import { TARGET_SCORE_MAX, TARGET_SCORE_MIN, desiredGradeLabel } from "@micabo/core";

import { useI18n } from "@/lib/i18n/client";
import { localeBcp47 } from "@/lib/i18n/copy";

import { gradeCountry } from "./grade-country";

/**
 * La vignette de l'écran « quand, et quelle note ».
 *
 * Un calendrier et un curseur, **factices**. Ils ne collectent rien : la vraie date se pose
 * plus tard, dans l'app, quand il y a des cours à mettre au programme. Ici on montre la seule
 * chose qui distingue Micabo d'une pile de cartes - le produit part d'une date et d'une
 * ambition, et en déduit le travail - et on la montre plutôt que de l'écrire.
 *
 * Le curseur bouge tout seul une fois, à l'arrivée. Un contrôle immobile se lit comme une
 * image ; un contrôle qui se déplace se lit comme quelque chose qu'on pourra régler.
 */
export function ExamDateStory() {
  const { t, locale } = useI18n();
  const bcp = localeBcp47(locale);
  const [score, setScore] = useState(TARGET_SCORE_MIN + 2);

  // Le mois de l'examen : trois semaines devant, comme dans la vraie création d'un plan.
  const today = new Date();
  const exam = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 21);
  const monthStart = new Date(exam.getFullYear(), exam.getMonth(), 1);
  const monthLabel = monthStart.toLocaleDateString(bcp, { month: "long", year: "numeric" });
  const daysInMonth = new Date(exam.getFullYear(), exam.getMonth() + 1, 0).getDate();
  // Lundi en tête, comme partout ailleurs dans le produit.
  const offset = (monthStart.getDay() + 6) % 7;
  const cells = [...Array<null>(offset).fill(null), ...range(1, daysInMonth)];
  const weekdays = weekdayInitials(bcp);

  useEffect(() => {
    const id = window.setTimeout(() => setScore(TARGET_SCORE_MAX - 1), 700);
    return () => window.clearTimeout(id);
  }, []);

  const filled = (score - TARGET_SCORE_MIN) / (TARGET_SCORE_MAX - TARGET_SCORE_MIN);

  return (
    <div className="relative w-full max-w-[320px] pb-24">
      <div className="paper rounded-[18px] bg-surface px-4 py-4">
        <p className="text-center text-[14px] font-semibold capitalize text-ink">{monthLabel}</p>

        <div className="mt-3 grid grid-cols-7 gap-y-1.5 text-center">
          {weekdays.map((day, index) => (
            <span key={index} className="text-[10.5px] font-medium text-ink-tertiary">
              {day}
            </span>
          ))}
          {cells.map((day, index) =>
            day === null ? (
              <span key={`vide-${index}`} />
            ) : (
              <span
                key={day}
                className={`numeral mx-auto flex h-6 w-6 items-center justify-center rounded-[7px] text-[11.5px] ${
                  day === exam.getDate()
                    ? "bg-accent-soft font-semibold text-accent shadow-[inset_0_0_0_1.5px_var(--color-accent)]"
                    : "text-ink-secondary"
                }`}
              >
                {day}
              </span>
            ),
          )}
        </div>
      </div>

      {/* La note chevauche le calendrier : les deux réponses ne font qu'une décision. */}
      <div className="paper absolute inset-x-4 bottom-0 rounded-[18px] bg-surface px-4 pb-3.5 pt-3">
        <p className="numeral text-center text-[40px] font-semibold leading-none tracking-tight text-ink">
          {desiredGradeLabel(score, gradeCountry(locale))}
        </p>
        <div className="mt-3 flex items-center gap-2">
          <span className="text-[10px] text-ink-tertiary">
            {desiredGradeLabel(TARGET_SCORE_MIN, gradeCountry(locale))}
          </span>
          <span className="relative h-1 min-w-0 flex-1 rounded-pill bg-surface-sunken">
            <span
              className="absolute inset-y-0 left-0 rounded-pill bg-accent transition-[width] duration-slow ease-out-strong"
              style={{ width: `${filled * 100}%` }}
            />
            <span
              aria-hidden
              className="absolute top-1/2 h-3.5 w-3.5 -translate-x-1/2 -translate-y-1/2 rounded-full bg-surface shadow-[0_1px_4px_rgba(25,23,20,0.3)] transition-[left] duration-slow ease-out-strong"
              style={{ left: `${filled * 100}%` }}
            />
          </span>
          <span className="text-[10px] text-ink-tertiary">
            {desiredGradeLabel(TARGET_SCORE_MAX, gradeCountry(locale))}
          </span>
        </div>
        <p className="mt-1.5 text-center text-[10.5px] text-ink-tertiary">
          {t("onboarding.examenSliderHint")}
        </p>
      </div>
    </div>
  );
}

function range(from: number, to: number): number[] {
  return Array.from({ length: to - from + 1 }, (_, index) => from + index);
}

/** Les initiales des jours, dans la langue du site, lundi en tête. */
function weekdayInitials(bcp: string): string[] {
  const reference = new Date(2024, 0, 1); // un lundi
  return Array.from({ length: 7 }, (_, index) => {
    const day = new Date(reference.getTime());
    day.setDate(day.getDate() + index);
    return day.toLocaleDateString(bcp, { weekday: "short" }).replace(".", "").slice(0, 2);
  });
}
