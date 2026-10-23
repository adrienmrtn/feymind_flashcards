"use client";

import type { Route } from "next";
import Link from "next/link";

import { useI18n } from "@/lib/i18n/client";

import { HeroDemo } from "./HeroDemo";

/**
 * **L'accroche** : une phrase, une ligne, deux boutons — et à droite, la carte qui montre ce
 * que fait le produit, en boucle : quatre supports entrent, on génère, la leçon apparaît.
 *
 * L'entrée est orchestrée : le bandeau, le titre, la phrase, les boutons et la carte montent
 * l'un après l'autre, 70 ms d'écart, sur la même courbe (`lp-enter`). Le mot accentué porte
 * le dégradé du titre de Home dans l'app : le bleu de Micabo vers le violet des mots-clés.
 *
 * Aucun chiffre d'utilisateurs sous le bouton : il n'y en a pas encore qu'on puisse écrire.
 * À la place, ce qui est vrai pour tout le monde — la première leçon est offerte.
 */
export function Hero({ signedIn = false }: { signedIn?: boolean }) {
  const { t } = useI18n();
  return (
    <section className="relative">
      <div className="mx-auto grid max-w-page items-center gap-4 px-screen sm:gap-12 pb-6 pt-10 sm:pt-14 lg:grid-cols-[1.05fr_1fr] lg:gap-8 lg:pb-10 lg:pt-16">
        <div className="text-center lg:text-left">
          <p
            className="lp-enter inline-flex items-center gap-2 rounded-pill bg-surface/75 px-3.5 py-1.5 text-[13px] font-bold text-ink-secondary shadow-paper backdrop-blur-sm"
            style={{ ["--i" as string]: 0 }}
          >
            <PlatformIcons />
            {t("landing.heroBadge")}
          </p>

          <h1
            className="lp-enter mx-auto mt-6 max-w-[15ch] text-balance text-[42px] font-extrabold leading-[1.02] tracking-display text-ink sm:text-[58px] lg:mx-0 lg:text-[66px]"
            style={{ ["--i" as string]: 1 }}
          >
            {t("landing.titleBefore")} <span className="home-gradient-text">{t("landing.titleAccent")}</span>.
          </h1>

          <p
            className="lp-enter mx-auto mt-6 max-w-[44ch] text-[17px] leading-relaxed text-ink-secondary sm:text-[19px] lg:mx-0"
            style={{ ["--i" as string]: 2 }}
          >
            {t("landing.heroSubtitle")}
          </p>

          <div
            className="lp-enter mt-9 flex flex-col items-center gap-3 sm:flex-row sm:justify-center lg:justify-start"
            style={{ ["--i" as string]: 3 }}
          >
            <PrimaryCta signedIn={signedIn} />
            {signedIn ? null : (
              <Link
                href={"/connexion" as Route}
                className="lp-card inline-flex h-14 w-full items-center justify-center rounded-[18px] bg-surface/80 px-6 text-[16px] font-bold text-ink shadow-paper backdrop-blur-sm sm:w-auto dark:ring-1 dark:ring-stroke-strong"
              >
                {t("common.alreadyAccount")}
              </Link>
            )}
          </div>

          <p
            className="lp-enter mt-5 flex items-center justify-center gap-2 text-[13.5px] font-semibold text-ink-tertiary lg:justify-start"
            style={{ ["--i" as string]: 4 }}
          >
            <span className="flex size-[18px] items-center justify-center rounded-full bg-correct-soft text-correct-ink">
              <svg aria-hidden viewBox="0 0 16 16" className="size-3" fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round">
                <path d="m3.5 8.4 2.9 2.9 6.1-6.6" />
              </svg>
            </span>
            {t("landing.heroNote")}
          </p>
        </div>

        <div className="lp-enter" style={{ ["--i" as string]: 4 }}>
          <HeroDemo />
        </div>
      </div>
    </section>
  );
}

/**
 * Le bouton qui compte : il ouvre le parcours d'inscription, ou l'app si une session est là.
 */
export function PrimaryCta({ signedIn = false, className = "" }: { signedIn?: boolean; className?: string }) {
  const { t } = useI18n();
  return (
    <Link
      href={signedIn ? "/app" : "/commencer"}
      className={`lp-cta inline-flex h-14 w-full items-center justify-center gap-2.5 rounded-[18px] bg-accent px-7 text-[16.5px] font-extrabold text-on-ink sm:w-auto ${className}`}
    >
      {signedIn ? t("common.openApp") : t("landing.heroCta")}
      <svg aria-hidden viewBox="0 0 20 20" className="lp-arrow size-[18px]" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M4 10h11M11 5l5 5-5 5" />
      </svg>
    </Link>
  );
}

/** La pomme et le robot, en petit : les deux téléphones sur lesquels l'app existe. */
function PlatformIcons() {
  return (
    <span aria-hidden className="flex items-center gap-1 text-ink">
      <svg viewBox="0 0 24 24" className="size-[15px]" fill="currentColor">
        <path d="M16.5 12.6c0-2 1.6-3 1.7-3.1-.9-1.4-2.4-1.5-2.9-1.6-1.2-.1-2.4.7-3 .7-.6 0-1.6-.7-2.6-.7-1.3 0-2.6.8-3.3 2-1.4 2.4-.4 6 1 7.9.7.9 1.5 2 2.5 2 1 0 1.3-.6 2.5-.6s1.5.6 2.5.6 1.7-.9 2.4-1.9c.5-.7.7-1.1.9-1.6-2.3-.9-2.2-3.6-2.2-3.7zM14.6 5.9c.5-.6.9-1.5.8-2.4-.8 0-1.7.5-2.3 1.2-.5.6-.9 1.5-.8 2.3.9.1 1.8-.4 2.3-1.1z" />
      </svg>
      <svg viewBox="0 0 24 24" className="size-[15px]" fill="currentColor">
        <path d="M7.2 9.2h9.6v7.3c0 .6-.5 1.1-1.1 1.1h-.8v2.3a1.1 1.1 0 0 1-2.2 0v-2.3h-1.4v2.3a1.1 1.1 0 0 1-2.2 0v-2.3h-.8c-.6 0-1.1-.5-1.1-1.1zM5 9.3a1.1 1.1 0 0 1 2.2 0v4.6a1.1 1.1 0 0 1-2.2 0zm11.8 0a1.1 1.1 0 0 1 2.2 0v4.6a1.1 1.1 0 0 1-2.2 0zM7.3 8.3a4.7 4.7 0 0 1 2.4-3.5l-.8-1.4a.3.3 0 0 1 .5-.3l.8 1.4a5.2 5.2 0 0 1 3.6 0l.8-1.4a.3.3 0 0 1 .5.3l-.8 1.4a4.7 4.7 0 0 1 2.4 3.5zm2.6-1.6a.5.5 0 1 0 0-1 .5.5 0 0 0 0 1zm4.2 0a.5.5 0 1 0 0-1 .5.5 0 0 0 0 1z" />
      </svg>
    </span>
  );
}
