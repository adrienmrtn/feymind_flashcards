"use client";

import { useEffect, useState } from "react";
import type { Route } from "next";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";

import { SignOutButton } from "@/components/app/SignOutButton";
import { ONBOARDING_REPLAY_STORAGE } from "@/lib/auth/onboarding-replay";
import { OnboardingStore } from "@/lib/onboarding/store";
import { previousPath, progressFor, stepIndex, STEPS } from "@/lib/onboarding/steps";
import { createClient } from "@/lib/supabase/client";

/**
 * L'habillage du parcours : la barre de progression, et le retour.
 *
 * La jauge et le retour sont là dès le premier écran. Le retour du pays ramène
 * à la landing : le parcours n'est pas la vitrine. Le compte n'a plus de jauge :
 * c'est une page, et elle arrive à la fin.
 */
export default function OnboardingLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const index = stepIndex(pathname);
  const step = index >= 0 ? STEPS[index] : undefined;
  const showChrome = step?.chrome ?? false;
  const back = previousPath(pathname);
  const progress = progressFor(pathname);

  return (
    <OnboardingStore>
      <LoggedInBounce />
      <div
        className="min-h-svh bg-canvas"
        style={{ ["--onboarding-chrome" as string]: showChrome ? "56px" : "16px" }}
      >
        {showChrome ? (
          <header className="flex h-14 items-center gap-4 px-screen">
            {back ? (
              <Link
                href={back as Route}
                aria-label={back === "/" ? "Retour à l'accueil" : "Revenir à l'écran précédent"}
                className="pressable -ml-1 flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-ink-secondary"
              >
                <svg aria-hidden viewBox="0 0 20 20" className="h-5 w-5">
                  <path
                    d="M12 4l-6 6 6 6"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                </svg>
              </Link>
            ) : (
              <span className="h-9 w-9 shrink-0" />
            )}

            <div
              className="h-1 flex-1 overflow-hidden rounded-pill bg-progress-track"
              role="progressbar"
              aria-valuemin={0}
              aria-valuemax={100}
              aria-valuenow={Math.round(progress * 100)}
              aria-label={`Étape ${step?.label ?? ""}`}
            >
              <div
                className="h-full rounded-pill bg-progress transition-[width] duration-menu ease-out-strong"
                style={{ width: `${progress * 100}%` }}
              />
            </div>

            {/* La place du retour, rendue à droite : sans elle, la jauge n'est pas centrée.
                S'il y a une session (on rejoue le parcours), c'est aussi là qu'on la ferme. */}
            <OnboardingLogout />
          </header>
        ) : null}

        {children}
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

/** Une session ouverte n'a plus rien à faire dans le tunnel — sauf créer le compte. */
function LoggedInBounce() {
  const pathname = usePathname();
  const router = useRouter();

  useEffect(() => {
    if (pathname === "/commencer/compte") return;
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
  }, [pathname, router]);

  return null;
}
