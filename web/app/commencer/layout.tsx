"use client";

import { Suspense, useEffect, useRef } from "react";
import type { Route } from "next";
import { usePathname, useRouter } from "next/navigation";

import { BrandLockup } from "@/components/BrandMark";
import { LanguageSwitcher } from "@/components/i18n/LanguageSwitcher";
import { Atmosphere } from "@/components/landing/Atmosphere";
import { Mika } from "@/components/mika/Mika";
import type { MikaMood } from "@/components/mika/moods";
import { trackOnboardingStep } from "@/lib/analytics/funnel";
import { ONBOARDING_REPLAY_STORAGE } from "@/lib/auth/onboarding-replay";
import { useI18n } from "@/lib/i18n/client";
import { prefetchStep } from "@/lib/onboarding/prefetch";
import { OnboardingStore, useOnboarding } from "@/lib/onboarding/store";
import { progressFor, stepIndex, STEPS, visibleSteps } from "@/lib/onboarding/steps";
import { createClient } from "@/lib/supabase/client";

/**
 * L'habillage du parcours : **la carte de la vitrine**, posée sur son lavage d'ambiance, avec
 * Mika perché sur le bord.
 *
 * C'est la forme de la page de connexion et de la carte du héros : le parcours qu'on ouvre
 * depuis la vitrine ne change pas de monde au premier clic. La carte **garde la même taille
 * d'un écran à l'autre** - un cadre qui change de forme fait trembler le parcours, et
 * l'étudiant réapprend où regarder à chaque clic. Elle est plus étroite qu'avant (640 et non
 * 940) : les écrans de démonstration à deux colonnes sont partis, et une question se lit
 * mieux sur une colonne.
 *
 * **Mika change d'humeur avec l'écran** : il salue à l'accueil, réfléchit sur ce qui bloque,
 * se réjouit d'un objectif, fait la fête quand le plan est prêt. Ce n'est pas un décor : c'est
 * lui qui écrira les leçons, et c'est à lui qu'on répond.
 *
 * La jauge tient toute la largeur de la carte, et compte les écrans **que cet étudiant-là
 * traverse** : l'année ne se pose qu'à certains pays, et une jauge qui saute un cran au
 * milieu se lit comme un bug.
 */
export default function OnboardingLayout({ children }: { children: React.ReactNode }) {
  return (
    <OnboardingStore>
      <Suspense fallback={null}>
        <LoggedInBounce />
      </Suspense>
      <Frame>{children}</Frame>
    </OnboardingStore>
  );
}

const MOODS: Partial<Record<string, MikaMood>> = {
  "/commencer/freins": "think",
  "/commencer/moyenne": "happy",
  "/commencer/examen": "think",
  "/commencer/parcours": "celebrate",
  "/commencer/compte": "wave",
  "/commencer/offre": "celebrate",
};

function Frame({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const { t } = useI18n();
  const { answers } = useOnboarding();
  const context = { country: answers.country, trackId: answers.trackId };
  const index = stepIndex(pathname);
  const step = index >= 0 ? STEPS[index] : undefined;
  const showChrome = step?.chrome ?? false;
  const isWelcome = pathname === "/commencer/bienvenue";
  const progress = progressFor(pathname, context);
  const stepLabel = step ? t(step.labelKey) : "";
  const questions = visibleSteps(context).filter((candidate) => candidate.chrome);
  const position = questions.findIndex((candidate) => candidate.path === pathname) + 1;

  /**
   * Le sens du mouvement : on avance vers la droite, on revient vers la gauche.
   *
   * Il se calcule **pendant le rendu**, contre l'écran précédent, et la mémoire ne se met à
   * jour qu'après. Le faire dans l'effet donnerait une première image dans le mauvais sens :
   * l'effet passe après la peinture, et l'animation a déjà commencé.
   */
  const previousIndex = useRef(index);
  const direction = index >= previousIndex.current ? "forward" : "back";
  useEffect(() => {
    previousIndex.current = index;
  }, [index]);

  /**
   * **Une marche de l'entonnoir par écran.** Les pages vues de Vercel comptent déjà les
   * adresses, mais elles ne se lisent pas comme un parcours ; l'événement porte le numéro
   * de la marche, et le tableau des événements se lit dans l'ordre, jusqu'à l'offre.
   */
  useEffect(() => {
    trackOnboardingStep(pathname);
  }, [pathname]);

  /**
   * **Tout le parcours est chargé dès le premier écran.** Ce sont des pages statiques de
   * quelques kilo-octets : les précharger toutes à l'accueil rend chaque « Continuer »
   * instantané, au lieu d'attendre le réseau à chaque marche. L'offre n'en fait pas partie :
   * elle demande une session, et se charge depuis le compte.
   */
  useEffect(() => {
    for (const candidate of STEPS) {
      if (candidate.path !== "/commencer/offre") prefetchStep(router, candidate.path);
    }
  }, [router]);

  const mood: MikaMood = MOODS[pathname] ?? "idle";
  const showsLanguage = isWelcome || pathname === "/commencer/compte";

  return (
    <div className="lp relative isolate flex min-h-svh flex-col overflow-hidden">
      <Atmosphere boxed />

      <header className="mx-auto flex h-14 w-full max-w-page shrink-0 items-center justify-between gap-3 px-screen">
        <BrandLockup href={"/" as Route} size={28} className="text-ink" wordClassName="text-[15px] font-bold text-ink" />
        {showsLanguage ? <LanguageSwitcher /> : null}
      </header>

      <main id="contenu" className="flex flex-1 items-start justify-center px-3 pb-3 pt-11 sm:items-center sm:px-6 sm:pb-8">
        <div className="relative w-full max-w-[640px]">
          {/* Mika, perché sur le bord de la carte, comme sur la connexion. L'accueil le pose
              en grand dans la carte : il n'est pas deux fois à l'écran. */}
          {isWelcome ? null : (
            <div aria-hidden className="absolute left-1/2 top-[-52px] z-10 w-[64px] -translate-x-1/2">
              <Mika mood={mood} label="" />
            </div>
          )}

          <div
            data-step-dir={direction}
            className="lp-demo-card flex h-[min(780px,calc(100svh-7.25rem))] w-full flex-col overflow-hidden rounded-[28px] bg-surface sm:h-[min(680px,calc(100svh-9rem))]"
          >
            {showChrome ? (
              <div className="flex shrink-0 items-center gap-3 px-6 pt-7 sm:px-10 sm:pt-8">
                <div
                  className="h-1.5 flex-1 overflow-hidden rounded-pill bg-progress-track"
                  role="progressbar"
                  aria-valuemin={0}
                  aria-valuemax={100}
                  aria-valuenow={Math.round(progress * 100)}
                  aria-label={t("onboarding.progressAria", { label: stepLabel })}
                >
                  <div
                    className="h-full rounded-pill bg-accent transition-[width] duration-menu ease-out-strong"
                    style={{ width: `${Math.max(4, progress * 100)}%` }}
                  />
                </div>
                <span aria-hidden className="numeral w-9 shrink-0 text-end text-[12.5px] font-bold text-ink-tertiary">
                  {position}/{questions.length}
                </span>
              </div>
            ) : null}

            {children}
          </div>
        </div>
      </main>
    </div>
  );
}

/**
 * Une session ouverte n'a plus rien à faire dans le tunnel - sauf sur l'offre, qui vient
 * justement après le compte.
 *
 * `getSession` et non `getUser` : la session se lit dans le stockage du navigateur, sans aller
 * jusqu'au serveur d'authentification. Le middleware a déjà renvoyé une session ouverte vers
 * l'app ; ceci ne rattrape que celle qui s'ouvre pendant qu'on est là.
 */
function LoggedInBounce() {
  const router = useRouter();
  const pathname = usePathname();
  const onOffer = pathname === "/commencer/offre";
  const current = useRef(pathname);
  useEffect(() => {
    current.current = pathname;
  }, [pathname]);

  useEffect(() => {
    if (onOffer) return;
    try {
      if (sessionStorage.getItem(ONBOARDING_REPLAY_STORAGE) === "1") return;
    } catch {
      // Stockage refusé : le cookie du middleware décide encore.
    }
    const supabase = createClient();
    // Le compte décide lui-même où aller une fois la session ouverte : c'est l'offre.
    const go = () => {
      if (current.current !== "/commencer/compte") router.replace("/app");
    };
    void supabase.auth.getSession().then(({ data }) => {
      if (data.session) go();
    });
    const { data } = supabase.auth.onAuthStateChange((_event, session) => {
      if (session) go();
    });
    return () => data.subscription.unsubscribe();
  }, [onOffer, router]);

  return null;
}
