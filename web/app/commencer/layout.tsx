"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

import { OnboardingStore } from "@/lib/onboarding/store";
import { previousPath, progressFor, stepIndex, STEPS } from "@/lib/onboarding/steps";

/**
 * L'habillage du parcours : la barre de progression, et le retour.
 *
 * Les deux n'apparaissent qu'**à partir de l'écran 2**, parce qu'avant il n'y a rien derrière soi.
 * Et la jauge est unique du premier écran au paywall, sans jamais disparaître : c'est une règle du
 * tunnel iOS, et elle vaut ici pour la même raison — une barre qui s'absente sur un écran fait
 * croire qu'on a quitté le parcours.
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
      <div
        className="min-h-svh bg-canvas"
        style={{ ["--onboarding-chrome" as string]: showChrome ? "56px" : "16px" }}
      >
        {showChrome ? (
          <header className="flex h-14 items-center gap-4 px-screen">
            {back ? (
              <Link
                href={back}
                aria-label="Revenir à l'écran précédent"
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

            {/* La place du retour, rendue à droite : sans elle, la jauge n'est pas centrée. */}
            <span className="h-9 w-9 shrink-0" />
          </header>
        ) : null}

        {children}
      </div>
    </OnboardingStore>
  );
}
