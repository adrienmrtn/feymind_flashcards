"use client";

import { useEffect, useMemo, useState } from "react";

import { ContinueButton, Scaffold, useAdvance } from "@/components/onboarding/Scaffold";
import { trackOnboardingAnswer } from "@/lib/analytics/funnel";
import { localeBcp47 } from "@/lib/i18n/copy";
import { useI18n } from "@/lib/i18n/client";
import { isExamDate } from "@/lib/onboarding/questions";
import { useOnboarding } from "@/lib/onboarding/store";

function isoDay(date: Date): string {
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60_000);
  return local.toISOString().slice(0, 10);
}

/**
 * **La date du prochain examen.**
 *
 * C'est la seule réponse qui crée quelque chose de visible dès l'arrivée : une ligne `exams`, avec
 * la moyenne visée comme objectif. Le mode examen compte les jours qui restent, et le plan se
 * cale dessus dès la première leçon rattachée.
 *
 * Beaucoup d'étudiants n'ont pas encore de date, et c'est une réponse : « Pas encore de date »
 * avance d'un appui, sans rien créer. Le champ est le sélecteur de date du système - sur un
 * téléphone, c'est la roue qu'on connaît déjà.
 */
export default function ExamDateStep() {
  const { answers, set, ready } = useOnboarding();
  const { t, locale } = useI18n();
  const advance = useAdvance();
  // Les bornes se calculent sur l'appareil, à son fuseau : le serveur rend la page dans le sien.
  const [bounds, setBounds] = useState<{ min: string; max: string } | null>(null);
  useEffect(() => {
    const today = new Date();
    setBounds({ min: isoDay(today), max: isoDay(new Date(today.getTime() + 3 * 365 * 86_400_000)) });
  }, []);
  const value = answers.examDate ?? "";
  const valid = isExamDate(value);

  const spelled = useMemo(() => {
    if (!valid) return null;
    try {
      return new Date(`${value}T12:00:00`).toLocaleDateString(localeBcp47(locale), {
        weekday: "long",
        day: "numeric",
        month: "long",
        year: "numeric",
      });
    } catch {
      return null;
    }
  }, [locale, valid, value]);

  return (
    <Scaffold
      title={t("onboarding.examTitle")}
      lead={t("onboarding.examLead")}
      footer={
        <ContinueButton
          enabled={valid && ready}
          onPress={() => {
            trackOnboardingAnswer("examDate", "set");
            advance();
          }}
        />
      }
      center
    >
      <label htmlFor="exam-date" className="sr-only">
        {t("onboarding.examDateLabel")}
      </label>
      <input
        id="exam-date"
        type="date"
        min={bounds?.min}
        max={bounds?.max}
        value={value}
        onChange={(event) => set({ examDate: event.target.value || undefined })}
        className="h-14 w-full rounded-[16px] border-[1.5px] border-stroke bg-surface px-4 text-center text-[17px] font-bold text-ink outline-none transition-colors duration-hover focus:border-accent [color-scheme:light] dark:[color-scheme:dark]"
      />
      <p className="mt-2 h-5 text-center text-[13.5px] font-semibold text-accent first-letter:uppercase" aria-live="polite">
        {spelled}
      </p>

      <button
        type="button"
        onClick={() => {
          set({ examDate: undefined });
          trackOnboardingAnswer("examDate", "none");
          advance({ auto: true });
        }}
        className="pressable mx-auto mt-5 flex min-h-12 items-center justify-center gap-2 rounded-[16px] border-[1.5px] border-stroke bg-surface px-5 text-[15px] font-semibold text-ink-secondary transition-colors duration-hover hover:border-stroke-strong hover:text-ink"
      >
        <span aria-hidden className="emoji text-[18px]">
          🤷
        </span>
        {t("onboarding.examNoDate")}
      </button>
    </Scaffold>
  );
}
