"use client";

import { useI18n } from "@/lib/i18n/client";

/**
 * La vignette du plan : **une journée par ligne, jusqu'au jour J.**
 *
 * C'est l'écran qui doit faire la différence avec une pile de cartes, et il ne la fait qu'à
 * une condition : montrer que chaque jour porte un travail **nommé**. « Réviser 30 minutes »
 * ne se distingue pas d'un minuteur ; « QCM sur le chapitre 3 » est un devoir, et un devoir se
 * fait. Les lignes arrivent l'une après l'autre pour qu'on lise le plan dans le sens du temps,
 * et la dernière est l'épreuve, qui ferme la liste comme elle ferme la période.
 */
export function PlanStory() {
  const { t } = useI18n();

  const days = [
    { day: t("onboarding.planMon"), task: t("onboarding.planMonTask"), tone: "work" as const },
    { day: t("onboarding.planTue"), task: t("onboarding.planTueTask"), tone: "work" as const },
    { day: t("onboarding.planWed"), task: t("onboarding.planWedTask"), tone: "soft" as const },
    { day: t("onboarding.planThu"), task: t("onboarding.planThuTask"), tone: "work" as const },
    { day: t("onboarding.planFri"), task: t("onboarding.planFriTask"), tone: "exam" as const },
  ];

  return (
    <ol className="w-full max-w-[330px] space-y-2">
      {days.map((entry, index) => (
        <li
          key={entry.day}
          className={`paper flex items-center gap-3 rounded-[14px] px-3.5 py-3 ${
            entry.tone === "exam" ? "bg-caution-soft" : "bg-surface"
          }`}
          style={{ animation: `micabo-rise 420ms var(--ease-out-strong) ${index * 110}ms both` }}
        >
          <span
            aria-hidden
            className={`h-8 w-1 shrink-0 rounded-pill ${
              entry.tone === "exam"
                ? "bg-caution"
                : entry.tone === "soft"
                  ? "bg-stroke-strong"
                  : "bg-accent"
            }`}
          />
          <span className="min-w-0 flex-1">
            <span className="block text-[11px] font-semibold uppercase tracking-wide text-ink-tertiary">
              {entry.day}
            </span>
            <span className="mt-0.5 block truncate text-[13.5px] font-medium text-ink">
              {entry.task}
            </span>
          </span>
        </li>
      ))}
    </ol>
  );
}
