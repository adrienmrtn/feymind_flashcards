"use client";

import { useMemo } from "react";

import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";
import { trackOnboardingAnswer } from "@/lib/analytics/funnel";
import { useI18n } from "@/lib/i18n/client";
import { DAILY_MINUTES } from "@/lib/onboarding/questions";
import { useOnboarding } from "@/lib/onboarding/store";
import { weekDays } from "@/lib/onboarding/week";

/**
 * **Le rythme** : le temps par jour, et les jours sans révision. Un seul écran pour une seule
 * question - « quand est-ce que tu travailles ? » - posée en deux temps.
 *
 * Les deux réponses vont dans `profiles`, là où l'app les relit :
 *
 * - **le temps par jour** devient `daily_minutes`, qui dose les cartes neuves de chaque jour
 *   sur l'iPhone et sur Android (`DailyLoad.newCardsPerDay`) - les quatre crans de l'iPhone ;
 * - **les jours de repos** deviennent des zéros dans `weekly_minutes` : le plan ne pose rien
 *   dessus. Un plan qui remplit les sept jours est un plan qu'on abandonne au premier dimanche
 *   manqué, parce qu'un retard non prévu se lit comme un échec.
 *
 * Ne cocher aucun jour est une réponse : celui qui révise tous les jours continue sans rien dire.
 */
export default function RhythmStep() {
  const { answers, set, ready } = useOnboarding();
  const { t, locale } = useI18n();
  const days = useMemo(() => weekDays(locale), [locale]);
  const rest = answers.restDays ?? [];
  const minutes = answers.dailyMinutes;

  function toggle(iso: number) {
    const next = rest.includes(iso) ? rest.filter((day) => day !== iso) : [...rest, iso];
    set({ restDays: next.sort((a, b) => a - b) });
  }

  return (
    <Scaffold title={t("onboarding.timeTitle")} footer={<ContinueButton enabled={minutes !== undefined && ready} />} center width="wide">
      <div role="group" aria-label={t("onboarding.timeTitle")} className="grid grid-cols-4 gap-2">
        {DAILY_MINUTES.map((choice) => {
          const selected = minutes === choice.minutes;
          return (
            <button
              key={choice.minutes}
              type="button"
              aria-pressed={selected}
              onClick={() => {
                set({ dailyMinutes: choice.minutes });
                trackOnboardingAnswer("dailyMinutes", choice.minutes);
              }}
              className={`pressable flex min-h-[104px] flex-col items-center justify-center gap-1 rounded-[18px] border-[1.5px] px-1 py-3 transition-colors duration-hover ${
                selected ? "border-accent bg-accent-soft" : "border-stroke bg-surface hover:border-stroke-strong"
              }`}
            >
              <span aria-hidden className="emoji text-[24px] leading-none">
                {choice.emoji}
              </span>
              <span className={`numeral mt-1 text-[17px] font-extrabold leading-none ${selected ? "text-accent" : "text-ink"}`}>
                {t("onboarding.timeMinutes", { n: choice.minutes })}
              </span>
              <span className="text-balance text-center text-[11.5px] font-semibold leading-tight text-ink-tertiary">
                {t(`onboarding.timeCaption${choice.minutes}`)}
              </span>
            </button>
          );
        })}
      </div>

      <div className="mt-7">
        <p className="text-center text-[15px] font-bold text-ink">{t("onboarding.reposTitle")}</p>
        <p className="mx-auto mt-1 max-w-[44ch] text-balance text-center text-[13.5px] leading-relaxed text-ink-secondary">
          {t("onboarding.reposLead")}
        </p>

        <div role="group" aria-label={t("onboarding.reposTitle")} className="mt-4 grid grid-cols-7 gap-1.5 sm:gap-2">
          {days.map((day) => {
            const off = rest.includes(day.iso);
            return (
              <button
                key={day.iso}
                type="button"
                onClick={() => toggle(day.iso)}
                aria-pressed={off}
                aria-label={day.full}
                title={day.full}
                /* Le jour choisi est **doux**, pas noir : sept cases pleines en encre font une
                   grille de deuil, alors qu'on parle de repos. L'accent le dit mieux. */
                className={`pressable flex h-[60px] flex-col items-center justify-center gap-0.5 rounded-[14px] border-[1.5px] transition-colors duration-hover ${
                  off ? "border-accent bg-accent-soft text-accent" : "border-stroke bg-surface text-ink hover:border-stroke-strong"
                }`}
              >
                <span className="text-[15px] font-bold uppercase leading-none">{day.initial}</span>
                {/* La case garde la même hauteur cochée ou non : sans cette ligne réservée, les
                    sept cases sautent d'un cran dès qu'on en touche une. */}
                <span className="flex h-[18px] items-center">
                  {off ? (
                    <span aria-hidden className="emoji emoji-pop text-[14px] leading-none">
                      💤
                    </span>
                  ) : null}
                </span>
              </button>
            );
          })}
        </div>

        <p className="mt-3 h-5 text-center text-[12.5px] font-medium text-ink-tertiary" aria-live="polite">
          {rest.length > 0 ? t("onboarding.reposCount", { count: rest.length }) : null}
        </p>
      </div>
    </Scaffold>
  );
}
