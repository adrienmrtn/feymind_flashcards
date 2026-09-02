"use client";

import { Suspense, useEffect, useState } from "react";
import { usePathname, useRouter } from "next/navigation";

import { SignOutButton } from "@/components/app/SignOutButton";
import { LanguageSwitcher } from "@/components/i18n/LanguageSwitcher";
import { ONBOARDING_REPLAY_STORAGE } from "@/lib/auth/onboarding-replay";
import { useI18n } from "@/lib/i18n/client";
import { OnboardingStore } from "@/lib/onboarding/store";
import { progressFor, stepIndex, STEPS } from "@/lib/onboarding/steps";
import { createClient } from "@/lib/supabase/client";

/**
 * L'habillage du parcours : une carte blanche sur le fond, pas tout l'écran.
 *
 * La jauge est en haut à gauche de la carte. Le retour et le bouton vivent
 * en bas, dans l'écran. Le compte n'a plus de jauge : c'est une page, et
 * elle arrive à la fin.
 */
export default function OnboardingLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const { t } = useI18n();
  const index = stepIndex(pathname);
  const step = index >= 0 ? STEPS[index] : undefined;
  const showChrome = step?.chrome ?? false;
  const progress = progressFor(pathname);
  const stepLabels = [
    t("onboarding.stepBienvenue"),
    t("onboarding.stepImporter"),
    t("onboarding.stepFiches"),
    t("onboarding.stepCartes"),
    t("onboarding.stepReussir"),
    t("onboarding.stepRetention"),
    t("onboarding.stepPersonnaliser"),
    t("onboarding.stepPays"),
    t("onboarding.stepNiveau"),
    t("onboarding.stepMatieres"),
    t("onboarding.stepEcole"),
    t("onboarding.stepParcours"),
    t("onboarding.stepCompte"),
  ];
  const stepLabel = index >= 0 ? stepLabels[index] : "";

  return (
    <OnboardingStore>
      <Suspense fallback={null}>
        <LoggedInBounce />
      </Suspense>
      <div className="flex min-h-svh items-center justify-center bg-canvas-sage px-3 py-3 sm:px-6 sm:py-6">
        <div className="flex h-[min(760px,calc(100svh-1.5rem))] w-full max-w-[720px] flex-col overflow-hidden rounded-[28px] bg-surface shadow-floating sm:h-[min(760px,calc(100svh-3rem))]">
          {showChrome ? (
            <header className="flex shrink-0 items-center gap-3 px-6 pt-5 sm:px-8">
              <div
                className="h-1 w-[72px] overflow-hidden rounded-pill bg-progress-track"
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
              <span className="flex-1" />
              <LanguageSwitcher />
              <OnboardingLogout />
            </header>
          ) : null}

          {children}
        </div>
      </div>
    </OnboardingStore>
  );
}

function OnboardingLogout() {
  const [signedIn, setSignedIn] = useState(false);

  useEffect(() => {
    const supabase = createClient();
    void supabase.auth.getUser().then(({ data }) => {
      setSignedIn(Boolean(data.user));
    });
  }, []);

  if (!signedIn) return <span className="h-9 w-9 shrink-0" />;
  return <SignOutButton compact />;
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
