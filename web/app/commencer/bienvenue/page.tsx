"use client";

import type { Route } from "next";
import Link from "next/link";
import { useEffect } from "react";
import { useRouter } from "next/navigation";

import { BrandMark } from "@/components/BrandMark";
import { useI18n } from "@/lib/i18n/client";

/**
 * La porte.
 *
 * Cet écran portait la charpente des autres : un titre calé à gauche, une jauge à zéro, un
 * bouton « Continuer » dans un coin, et le nom écrit **deux fois** - sous l'icône, puis en
 * accroche. Beaucoup de meubles pour une pièce où il n'y a rien à décider.
 *
 * Il n'a qu'un travail : dire de quoi il s'agit, et ouvrir. Le nom se pose donc **à côté** de
 * l'icône, une seule fois, comme une enseigne ; l'accroche tient sur une ligne ; et le bouton
 * est large et au milieu, parce qu'il est la seule chose à faire ici. Ni retour ni jauge : on
 * ne revient pas d'un premier écran, et un avancement à zéro annonce une file d'attente.
 */
export default function WelcomeStep() {
  const { t } = useI18n();
  const router = useRouter();

  // L'écran suivant est chargé pendant qu'on lit celui-ci : le premier « C'est parti » ne
  // doit pas être le plus lent du parcours.
  useEffect(() => {
    router.prefetch("/commencer/examen" as Route);
  }, [router]);

  return (
    <div className="flex min-h-0 flex-1 flex-col items-center justify-center px-6 pb-14 sm:px-14">
      <div className="rise flex w-full max-w-[520px] flex-col items-center">
        <div className="flex items-center gap-4">
          <BrandMark size={72} />
          <span className="text-[52px] font-bold leading-none tracking-tight-title text-ink">
            Micabo
          </span>
        </div>

        <p className="mt-7 text-center text-[17px] text-ink-secondary">
          {t("onboarding.welcomeTagline")}
        </p>

        <button
          type="button"
          onClick={() => router.push("/commencer/examen" as Route)}
          className="pressable mt-12 flex h-[60px] w-full items-center justify-center rounded-pill bg-accent text-[17px] font-semibold text-on-ink transition-colors duration-hover hover:bg-accent/90"
        >
          {t("onboarding.letsGo")}
        </button>

        <p className="mt-6 text-center text-[15px] text-ink-secondary">
          {t("onboarding.alreadyAccountQuestion")}{" "}
          <Link href={"/connexion" as Route} className="font-bold text-ink underline underline-offset-4">
            {t("onboarding.signIn")}
          </Link>
        </p>
      </div>
    </div>
  );
}
