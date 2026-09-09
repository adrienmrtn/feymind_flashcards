"use client";

import { TARGET_SCORE_MAX, desiredGradeLabel } from "@micabo/core";

import { useI18n } from "@/lib/i18n/client";

import { gradeCountry } from "./grade-country";

/**
 * La vignette de l'IA : **quatre façons d'être interrogé, montrées en petit.**
 *
 * Quatre tuiles plutôt qu'une liste de noms, parce que la différence entre ces formats est
 * visuelle avant d'être verbale : un QCM se reconnaît à ses puces, un texte à trou à sa ligne
 * vide, une carte à son recto muet. Le nom seul obligerait à imaginer ; la miniature dispense
 * d'imaginer.
 */
export function AiStory() {
  const { t, locale } = useI18n();

  return (
    <div className="grid w-full max-w-[330px] grid-cols-2 gap-3">
      <Tile title={t("onboarding.iaMock")}>
        <div className="flex items-stretch overflow-hidden rounded-[9px] bg-surface-muted">
          <span className="flex-1 px-2 py-1.5 text-center">
            <span className="block text-[8.5px] text-ink-tertiary">{t("onboarding.iaPoints")}</span>
            <span className="numeral block text-[13px] font-semibold text-ink">27/30</span>
          </span>
          <span className="w-px bg-stroke" />
          <span className="flex-1 px-2 py-1.5 text-center">
            <span className="block text-[8.5px] text-ink-tertiary">{t("onboarding.iaGrade")}</span>
            <span className="numeral block text-[13px] font-semibold text-accent">
              {desiredGradeLabel(TARGET_SCORE_MAX - 1, gradeCountry(locale))}
            </span>
          </span>
        </div>
      </Tile>

      <Tile title={t("onboarding.iaQuiz")}>
        <div className="space-y-1.5">
          {[false, true, false].map((right, index) => (
            <span key={index} className="flex items-center gap-1.5">
              <span
                aria-hidden
                className={`h-2.5 w-2.5 shrink-0 rounded-full ${
                  right ? "bg-accent" : "border border-stroke-strong"
                }`}
              />
              <span
                aria-hidden
                className={`h-1.5 rounded-pill ${right ? "bg-accent/40" : "bg-surface-sunken"}`}
                style={{ width: `${[70, 52, 62][index]}%` }}
              />
            </span>
          ))}
        </div>
      </Tile>

      <Tile title={t("onboarding.iaCard")}>
        <div className="relative h-[46px]">
          <span className="absolute inset-x-2 top-1.5 h-[38px] rounded-[9px] bg-surface-sunken" />
          <span className="paper absolute inset-x-0 top-0 flex h-[38px] items-center justify-center rounded-[9px] bg-surface">
            <span aria-hidden className="h-1.5 w-[56%] rounded-pill bg-stroke-strong" />
          </span>
        </div>
      </Tile>

      <Tile title={t("onboarding.iaCloze")}>
        <div className="space-y-1.5">
          <span className="flex items-center gap-1">
            <span aria-hidden className="h-1.5 w-8 rounded-pill bg-surface-sunken" />
            <span aria-hidden className="h-3.5 w-12 rounded-[4px] border border-dashed border-accent bg-accent-soft" />
            <span aria-hidden className="h-1.5 w-6 rounded-pill bg-surface-sunken" />
          </span>
          <span aria-hidden className="block h-1.5 w-[80%] rounded-pill bg-surface-sunken" />
          <span aria-hidden className="block h-1.5 w-[62%] rounded-pill bg-surface-sunken" />
        </div>
      </Tile>
    </div>
  );
}

function Tile({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="paper rounded-[14px] bg-surface px-3 py-2.5">
      <p className="text-center text-[11.5px] font-semibold text-ink">{title}</p>
      <div className="mt-2.5">{children}</div>
    </div>
  );
}
