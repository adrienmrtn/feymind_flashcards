"use client";

import { useMemo } from "react";

import { ContinueButton, Scaffold } from "@/components/onboarding/Scaffold";
import { useI18n } from "@/lib/i18n/client";
import { useOnboarding } from "@/lib/onboarding/store";
import { weekDays } from "@/lib/onboarding/week";

/**
 * **Les jours où l'on ne révise pas.**
 *
 * Un plan qui remplit les sept jours de la semaine est un plan qu'on abandonne au premier
 * dimanche manqué, parce qu'un retard non prévu se lit comme un échec. Le poser ici, avant que
 * quoi que ce soit ne soit calculé, change la nature du dimanche : il n'est plus un jour
 * perdu, il est un jour de repos, et le reste de la semaine a été construit avec.
 *
 * Une semaine, pas un calendrier. La question porte sur une **habitude** - « jamais le
 * dimanche » - et une habitude se décrit en sept cases. Les dates viendront plus tard, à la
 * création d'un plan, où l'on saura de quelles semaines on parle.
 *
 * Ne rien cocher est une réponse : celui qui révise tous les jours continue sans rien dire.
 */
export default function RestDaysStep() {
  const { answers, set, ready } = useOnboarding();
  const { t, locale } = useI18n();
  const days = useMemo(() => weekDays(locale), [locale]);
  const rest = answers.restDays ?? [];

  function toggle(iso: number) {
    const next = rest.includes(iso) ? rest.filter((day) => day !== iso) : [...rest, iso];
    set({ restDays: next.sort((a, b) => a - b) });
  }

  return (
    <Scaffold
      title={t("onboarding.reposTitle")}
      footer={<ContinueButton enabled={ready} href="/commencer/moyenne" />}
      width="wide"
      center
    >
      <p className="text-center text-[15px] leading-relaxed text-ink-secondary">
        {t("onboarding.reposLead")}
      </p>

      <div className="mt-7 grid grid-cols-7 gap-2">
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
              className={`pressable flex h-[104px] flex-col items-center justify-center gap-1.5 rounded-[14px] border transition-colors duration-hover ${
                off
                  ? "border-ink bg-ink text-on-ink"
                  : "border-hairline bg-surface-muted text-ink hover:bg-surface"
              }`}
            >
              <span className="text-[19px] font-semibold uppercase leading-none">
                {day.initial}
              </span>
              {/* La case garde la même hauteur cochée ou non : sans cette ligne réservée, les
                  sept cases sautent d'un cran dès qu'on en touche une. */}
              <span className="flex h-6 items-center">
                {off ? (
                  <span aria-hidden className="emoji emoji-pop text-[20px] leading-none">
                    💤
                  </span>
                ) : null}
              </span>
            </button>
          );
        })}
      </div>

      <p className="mt-5 h-5 text-center text-[13px] text-ink-tertiary">
        {rest.length > 0 ? t("onboarding.reposCount", { count: rest.length }) : null}
      </p>
    </Scaffold>
  );
}
