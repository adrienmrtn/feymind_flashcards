"use client";

import { useI18n } from "@/lib/i18n/client";

/**
 * La vignette de la méthode Feynman : **on explique à voix haute, la machine note.**
 *
 * C'est la seule promesse du parcours qu'un jeu de cartes ne peut pas tenir, donc la vignette
 * doit montrer le geste entier : la voix qui part, la note qui revient, et surtout **ce qui
 * manquait**. Une note seule flatte ou décourage ; c'est la ligne « tu n'as pas dit que… » qui
 * donne envie de recommencer, parce qu'elle transforme un échec en une chose à faire.
 *
 * Les barres du micro ondulent au même rythme que le vrai enregistrement, ce qui suffit à
 * faire lire « ça écoute » sans écrire « ça écoute ».
 */
const BARS = [8, 15, 22, 13, 26, 18, 30, 20, 12, 24, 16, 9];

export function FeynmanStory() {
  const { t } = useI18n();

  return (
    <div className="w-full max-w-[330px] space-y-3">
      <div className="paper rounded-[14px] bg-surface px-4 py-3.5">
        <div className="flex items-center gap-3">
          <span
            aria-hidden
            className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-accent text-on-ink"
          >
            <svg viewBox="0 0 24 24" className="h-4 w-4">
              <rect x="9" y="3" width="6" height="10.5" rx="3" fill="currentColor" />
              <path
                d="M5.8 11.5a6.2 6.2 0 0 0 12.4 0M12 17.7V21"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinecap="round"
              />
            </svg>
          </span>
          <span aria-hidden className="flex min-w-0 flex-1 items-center gap-[3px]">
            {BARS.map((height, index) => (
              <span
                key={index}
                className="w-[3px] shrink-0 rounded-pill bg-accent/70"
                style={{
                  height: `${height}px`,
                  animation: `micabo-float 1.4s var(--ease-in-out-strong) ${index * 90}ms infinite`,
                }}
              />
            ))}
          </span>
        </div>
        <p className="mt-3 text-[12px] italic leading-snug text-ink-secondary">
          {t("onboarding.feynmanSaid")}
        </p>
      </div>

      <div className="paper rounded-[14px] bg-surface px-4 py-3.5">
        <div className="flex items-center justify-between gap-3">
          <p className="text-[12px] font-semibold text-ink">{t("onboarding.feynmanScoreLabel")}</p>
          <p className="numeral text-[22px] font-semibold leading-none text-accent">79 %</p>
        </div>
        <span aria-hidden className="mt-2 block h-1.5 overflow-hidden rounded-pill bg-surface-sunken">
          <span className="block h-full rounded-pill bg-accent" style={{ width: "79%" }} />
        </span>
        <p className="mt-3 text-[11.5px] font-semibold uppercase tracking-wide text-ink-tertiary">
          {t("onboarding.feynmanGapsLabel")}
        </p>
        <ul className="mt-1.5 space-y-1">
          {[t("onboarding.feynmanGap1"), t("onboarding.feynmanGap2")].map((gap) => (
            <li key={gap} className="flex gap-1.5 text-[12px] leading-snug text-ink-secondary">
              <span aria-hidden className="mt-[6px] h-1 w-1 shrink-0 rounded-full bg-caution" />
              {gap}
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
