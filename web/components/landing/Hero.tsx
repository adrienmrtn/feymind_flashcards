"use client";

import { useI18n } from "@/lib/i18n/client";
import { LANDING_SECTIONS } from "@/lib/landing-sections";

import { AppShowcase } from "./AppShowcase";
import { HeroAura } from "./HeroAura";
import { StartButton } from "./StartButton";

/**
 * L'accroche : une phrase, une ligne de suite, le bouton, **et l'app dessous.**
 *
 * Le bandeau ne promet plus dans le vide : ce qui suit le bouton est l'app elle-même, dans
 * un cadre de navigateur, avec ses onglets qui se cliquent. Une accroche qui montre le
 * produit dans le premier écran n'a pas besoin d'un second paragraphe pour le décrire.
 */
export function Hero({ signedIn = false }: { signedIn?: boolean }) {
  const { t } = useI18n();
  return (
    <section className="relative overflow-clip">
      <HeroAura />

      <div className="relative mx-auto max-w-page px-screen pt-14 text-center sm:pt-20">
        <h1
          className="rise mx-auto max-w-[20ch] text-balance text-[40px] font-bold leading-[1.03] tracking-display text-ink sm:text-[72px]"
          style={{ animationDelay: "40ms" }}
        >
          {t("landing.titleBefore")}{" "}
          <span className="relative whitespace-nowrap text-accent">
            {t("landing.titleAccent")}
            <svg
              aria-hidden
              viewBox="0 0 200 12"
              preserveAspectRatio="none"
              className="absolute -bottom-1.5 left-0 h-2.5 w-full text-accent-vivid"
            >
              <path
                d="M2 8c40-5 90-7 196-4"
                fill="none"
                stroke="currentColor"
                strokeWidth="4"
                strokeLinecap="round"
              />
            </svg>
          </span>
          .
        </h1>

        <p
          className="rise mx-auto mt-7 max-w-[54ch] text-[17px] leading-relaxed text-ink-secondary sm:text-[19px]"
          style={{ animationDelay: "100ms" }}
        >
          {t("landing.subtitle")}
        </p>

        <div className="rise mt-9" style={{ animationDelay: "160ms" }}>
          <StartButton signedIn={signedIn} />
        </div>
      </div>

      <div id={LANDING_SECTIONS.app} className="relative mx-auto mt-14 max-w-page scroll-mt-20 px-screen sm:mt-20">
        <div className="rise" style={{ animationDelay: "240ms" }}>
          <AppShowcase />
        </div>
        <p className="mt-4 text-center text-[13px] text-ink-tertiary">{t("landing.showcaseCaption")}</p>
      </div>
    </section>
  );
}
