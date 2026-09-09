"use client";

import { useI18n } from "@/lib/i18n/client";

/**
 * La vignette du plan : **une journée par ligne, jusqu'au jour J.**
 *
 * C'est l'écran qui doit faire la différence avec une pile de cartes, et il ne la fait qu'à
 * une condition : montrer que chaque jour porte un travail **nommé**. « Réviser 30 minutes »
 * ne se distingue pas d'un minuteur ; « QCM sur le chapitre 3 » est un devoir, et un devoir
 * se fait. Les lignes arrivent l'une après l'autre pour qu'on lise le plan dans le sens du
 * temps, et la dernière est l'épreuve, qui ferme la liste comme elle ferme la période.
 *
 * Chaque ligne porte **une icône plutôt qu'un filet de couleur**. Un trait vertical bleu ou
 * gris disait seulement « chargé » ou « vide » ; le pictogramme dit de quoi il s'agit, et
 * cinq lignes se distinguent alors d'un coup d'œil au lieu de se lire une par une. Le jour et
 * la tâche tiennent sur la même ligne : la liste passait sous le pli sur un écran d'ordinateur
 * portable, et un plan qu'il faut faire défiler dans une démonstration n'est plus une
 * démonstration.
 */
type Glyph = "mock" | "quiz" | "rest" | "voice" | "exam";

export function PlanStory() {
  const { t } = useI18n();

  const days: { day: string; task: string; glyph: Glyph }[] = [
    { day: t("onboarding.planMon"), task: t("onboarding.planMonTask"), glyph: "mock" },
    { day: t("onboarding.planTue"), task: t("onboarding.planTueTask"), glyph: "quiz" },
    { day: t("onboarding.planWed"), task: t("onboarding.planWedTask"), glyph: "rest" },
    { day: t("onboarding.planThu"), task: t("onboarding.planThuTask"), glyph: "voice" },
    { day: t("onboarding.planFri"), task: t("onboarding.planFriTask"), glyph: "exam" },
  ];

  return (
    <ol className="w-full max-w-[330px] space-y-1.5">
      {days.map((entry, index) => (
        <li
          key={entry.day}
          className={`paper flex items-center gap-2.5 rounded-[12px] px-3 py-2 ${
            entry.glyph === "exam" ? "bg-caution-soft" : "bg-surface"
          }`}
          style={{ animation: `micabo-rise 420ms var(--ease-out-strong) ${index * 100}ms both` }}
        >
          <span
            aria-hidden
            className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-[8px] ${
              entry.glyph === "exam"
                ? "bg-caution/15 text-caution"
                : entry.glyph === "rest"
                  ? "bg-surface-sunken text-ink-tertiary"
                  : "bg-accent-soft text-accent"
            }`}
          >
            <DayGlyph name={entry.glyph} />
          </span>
          <span className="min-w-0 flex-1">
            <span className="block truncate text-[12.5px] font-medium leading-tight text-ink">
              {entry.task}
            </span>
            <span className="mt-0.5 block text-[10px] uppercase tracking-wide text-ink-tertiary">
              {entry.day}
            </span>
          </span>
        </li>
      ))}
    </ol>
  );
}

function DayGlyph({ name }: { name: Glyph }) {
  const size = "h-3.5 w-3.5";
  if (name === "mock") {
    return (
      <svg viewBox="0 0 20 20" className={size}>
        <circle cx="10" cy="11" r="6.6" fill="none" stroke="currentColor" strokeWidth="1.7" />
        <path
          d="M10 7.6V11l2.4 1.5M7.6 2.6h4.8"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.7"
          strokeLinecap="round"
        />
      </svg>
    );
  }
  if (name === "quiz") {
    return (
      <svg viewBox="0 0 20 20" className={size}>
        <circle cx="5" cy="6" r="1.6" fill="currentColor" />
        <circle cx="5" cy="13.4" r="1.6" fill="none" stroke="currentColor" strokeWidth="1.4" />
        <path
          d="M9.2 6h6.4M9.2 13.4h6.4"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.7"
          strokeLinecap="round"
        />
      </svg>
    );
  }
  if (name === "rest") {
    return (
      <svg viewBox="0 0 20 20" className={size}>
        <path
          d="M15.6 12.4A6.4 6.4 0 0 1 7.4 4.3a6.6 6.6 0 1 0 8.2 8.1z"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.7"
          strokeLinejoin="round"
        />
      </svg>
    );
  }
  if (name === "voice") {
    return (
      <svg viewBox="0 0 20 20" className={size}>
        <rect x="7.4" y="2.4" width="5.2" height="9" rx="2.6" fill="currentColor" />
        <path
          d="M4.6 9.6a5.4 5.4 0 0 0 10.8 0M10 15v2.6"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.7"
          strokeLinecap="round"
        />
      </svg>
    );
  }
  return (
    <svg viewBox="0 0 20 20" className={size}>
      <path d="M5 2.6v15" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
      <path d="M6 3.6h9.4l-2.6 3.4 2.6 3.4H6z" fill="currentColor" />
    </svg>
  );
}
