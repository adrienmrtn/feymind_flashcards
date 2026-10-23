"use client";

import { Mika } from "@/components/mika/Mika";
import { useI18n } from "@/lib/i18n/client";

import { Atmosphere } from "./Atmosphere";
import { PrimaryCta } from "./Hero";
import { Reveal } from "./Reveal";
import { StoreBadges } from "./StoreBadges";

/**
 * **Le dernier appel** : la même ambiance que le haut de page, tenue dans une carte, Mika qui
 * salue, une phrase, le bouton et les deux boutiques.
 */
export function Closing({ signedIn = false }: { signedIn?: boolean }) {
  const { t } = useI18n();
  return (
    <section className="mx-auto mt-28 max-w-page px-screen sm:mt-36">
      <Reveal>
        <div className="relative isolate overflow-hidden rounded-[36px] px-6 py-14 text-center lp-surface-shadow sm:px-12 sm:py-20">
          <Atmosphere boxed />
          <div className="mx-auto w-[96px]">
            <Mika mood="wave" label="" />
          </div>
          <h2 className="mx-auto mt-4 max-w-[24ch] text-balance text-[32px] font-extrabold leading-[1.06] tracking-display text-ink sm:text-[46px]">
            {t("landing.closingTitle")}
          </h2>
          <p className="mx-auto mt-4 max-w-[50ch] text-[16.5px] leading-relaxed text-ink-secondary">{t("landing.closingNote")}</p>
          <div className="mx-auto mt-9 flex max-w-[360px] justify-center sm:max-w-none">
            <PrimaryCta signedIn={signedIn} />
          </div>
          <StoreBadges className="mt-6 justify-center" size="small" />
        </div>
      </Reveal>
    </section>
  );
}
