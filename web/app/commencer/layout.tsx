"use client";

import { Suspense, useEffect } from "react";
import { usePathname, useRouter } from "next/navigation";

import { LanguageSwitcher } from "@/components/i18n/LanguageSwitcher";
import { ONBOARDING_REPLAY_STORAGE } from "@/lib/auth/onboarding-replay";
import { useI18n } from "@/lib/i18n/client";
import { OnboardingStore } from "@/lib/onboarding/store";
import { progressFor, stepIndex, STEPS } from "@/lib/onboarding/steps";
import { createClient } from "@/lib/supabase/client";

/**
 * L'habillage du parcours : **une seule carte, la même du premier écran au dernier.**
 *
 * Elle était étroite, haute de 760 px et large de 720. Ça allait tant que chaque écran ne
 * portait qu'une liste ; ça ne va plus, parce que les écrans de démonstration montrent
 * maintenant une chose à gauche et l'expliquent à droite, et deux colonnes dans 720 px ne
 * sont pas deux colonnes. La carte s'élargit donc à 1120, et **elle garde la même taille
 * partout** : un cadre qui change de forme d'un écran à l'autre donne un parcours qui
 * tremble, et l'étudiant réapprend où regarder à chaque clic.
 *
 * Deux choses ont quitté l'en-tête. Le **choix jour / nuit** n'a rien à faire dans un tunnel
 * d'inscription : c'est un réglage, il vit dans les réglages, et le poser ici invite à jouer
 * avec au lieu de répondre. La **jauge** ne s'affiche plus sur l'accueil : une barre à zéro
 * sur le premier écran annonce une file d'attente avant d'avoir rien montré. Reste la
 * **langue**, et seulement sur l'accueil, là où elle se décide.
 */
export default function OnboardingLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const { t } = useI18n();
  const index = stepIndex(pathname);
  const step = index >= 0 ? STEPS[index] : undefined;
  const showChrome = step?.chrome ?? false;
  const isWelcome = pathname === "/commencer/bienvenue";
  const progress = progressFor(pathname);
  const stepLabels = [
    t("onboarding.stepBienvenue"),
    t("onboarding.stepExamen"),
    t("onboarding.stepImporter"),
    t("onboarding.stepPlan"),
    t("onboarding.stepIa"),
    t("onboarding.stepFeynman"),
    t("onboarding.stepResultats"),
    t("onboarding.stepPersonnaliser"),
    t("onboarding.stepPays"),
    t("onboarding.stepNiveau"),
    t("onboarding.stepMatieres"),
    t("onboarding.stepEcole"),
    t("onboarding.stepParcours"),
    t("onboarding.stepCompte"),
  ];
  const stepLabel = (index >= 0 ? stepLabels[index] : undefined) ?? "";

  return (
    <OnboardingStore>
      <Suspense fallback={null}>
        <LoggedInBounce />
      </Suspense>
      <div className="flex min-h-svh items-center justify-center bg-canvas-sage px-3 py-3 sm:px-6 sm:py-6">
        <div className="flex h-[min(760px,calc(100svh-1.5rem))] w-full max-w-[1120px] flex-col overflow-hidden rounded-[28px] bg-surface shadow-floating sm:h-[min(760px,calc(100svh-3rem))]">
          {/*
            La jauge tient toute la largeur de la carte, et non un moignon de 72 px calé dans
            un coin. Un avancement se lit à la proportion : un trait court laisse deviner, un
            trait qui traverse l'écran se lit d'un regard.
          */}
          {showChrome ? (
            <div className="shrink-0 px-8 pt-6 sm:px-14">
              <div
                className="h-[3px] w-full overflow-hidden rounded-pill bg-progress-track"
                role="progressbar"
                aria-valuemin={0}
                aria-valuemax={100}
                aria-valuenow={Math.round(progress * 100)}
                aria-label={t("onboarding.progressAria", { label: stepLabel })}
              >
                <div
                  className="h-full rounded-pill bg-ink transition-[width] duration-menu ease-out-strong"
                  style={{ width: `${progress * 100}%` }}
                />
              </div>
            </div>
          ) : null}

          {isWelcome ? (
            <div className="flex shrink-0 justify-end px-6 pt-5 sm:px-8">
              <LanguageSwitcher />
            </div>
          ) : null}

          {children}
        </div>
      </div>
    </OnboardingStore>
  );
}

/** Une session ouverte n'a plus rien à faire dans le tunnel. */
function LoggedInBounce() {
  const router = useRouter();

  useEffect(() => {
    try {
      if (sessionStorage.getItem(ONBOARDING_REPLAY_STORAGE) === "1") return;
    } catch {
      // Stockage refusé : le cookie du middleware décide encore.
    }
    const supabase = createClient();
    const go = () => router.replace("/app");
    void supabase.auth.getUser().then(({ data }) => {
      if (data.user) go();
    });
    const { data } = supabase.auth.onAuthStateChange((_event, session) => {
      if (session) go();
    });
    return () => data.subscription.unsubscribe();
  }, [router]);

  return null;
}
