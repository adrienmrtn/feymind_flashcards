"use client";

import { useEffect } from "react";
import type { Route } from "next";
import Link from "next/link";

import { useAdvance } from "@/components/onboarding/Scaffold";
import { Mika } from "@/components/mika/Mika";
import { useI18n } from "@/lib/i18n/client";

/**
 * La porte.
 *
 * Un seul travail : dire de quoi il s'agit, et ouvrir. Mika salue au milieu de la carte - c'est
 * lui qui écrira les leçons, et le parcours est une conversation avec lui. L'accroche tient sur
 * deux lignes, et le bouton est large et au milieu, parce qu'il est la seule chose à faire ici.
 * Ni retour ni jauge : on ne revient pas d'un premier écran, et un avancement à zéro annonce
 * une file d'attente. Entrée l'appuie aussi, comme sur tous les écrans.
 */
export default function WelcomeStep() {
  const { t } = useI18n();
  const advance = useAdvance();

  return (
    <div className="flex min-h-0 flex-1 flex-col items-center justify-center px-6 pb-10 pt-6 sm:px-14">
      <div className="flex w-full max-w-[440px] flex-col items-center text-center">
        <div className="lp-enter w-[120px] sm:w-[136px]" style={{ ["--i" as string]: 0 }}>
          <Mika mood="wave" label="" />
        </div>

        <h1
          className="lp-enter mt-6 text-balance text-[30px] font-extrabold leading-[1.08] tracking-display text-ink sm:text-[38px]"
          style={{ ["--i" as string]: 1 }}
        >
          {t("onboarding.welcomeTagline")}
        </h1>

        <p className="lp-enter mt-4 max-w-[36ch] text-balance text-[15.5px] leading-relaxed text-ink-secondary sm:text-[16.5px]" style={{ ["--i" as string]: 2 }}>
          {t("onboarding.welcomeLead")}
        </p>

        <div className="lp-enter mt-9 w-full" style={{ ["--i" as string]: 3 }}>
          <WelcomeButton label={t("onboarding.letsGo")} onPress={() => advance()} />
        </div>

        <p className="lp-enter mt-6 text-[14.5px] text-ink-secondary" style={{ ["--i" as string]: 4 }}>
          {t("onboarding.alreadyAccountQuestion")}{" "}
          <Link href={"/connexion" as Route} className="underline-draw font-bold text-accent">
            {t("onboarding.signIn")}
          </Link>
        </p>
      </div>
    </div>
  );
}

function WelcomeButton({ label, onPress }: { label: string; onPress: () => void }) {
  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      if (event.key !== "Enter" || event.isComposing) return;
      if ((event.target as HTMLElement | null)?.closest("button, a, input, select, textarea")) return;
      event.preventDefault();
      onPress();
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onPress]);

  return (
    <button
      type="button"
      onClick={onPress}
      className="lp-cta inline-flex h-14 w-full items-center justify-center gap-2.5 rounded-[18px] bg-accent px-7 text-[16.5px] font-extrabold text-on-ink"
    >
      {label}
      <svg aria-hidden viewBox="0 0 20 20" className="lp-arrow size-[18px] rtl:-scale-x-100" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M4 10h11M11 5l5 5-5 5" />
      </svg>
    </button>
  );
}
