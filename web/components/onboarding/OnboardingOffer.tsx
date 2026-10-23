"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import type { Route } from "next";
import { useRouter } from "next/navigation";

import { PaywallCard } from "@/components/app/PaywallFlow";
import { paywallClosed } from "@/lib/discount";
import { useI18n } from "@/lib/i18n/client";
import { markPaywallDismissed, persistStoredAnswers } from "@/lib/onboarding/persist";
import { prefetchStep } from "@/lib/onboarding/prefetch";
import { useOnboarding } from "@/lib/onboarding/store";
import { PresentmentProvider } from "@/lib/presentment";

/**
 * L'offre posée sur la dernière carte du parcours.
 *
 * Derrière le voile, la carte dit que le compte est prêt : c'est ce qu'on voit une fraction de
 * seconde à l'arrivée, et c'est ce qui reste le temps que l'app s'ouvre une fois la croix
 * touchée. Le bouton « Ouvrir Micabo » y est aussi, pour qui aurait refermé l'offre sans que
 * la navigation ne parte.
 *
 * Trois choses en refermant, dans cet ordre :
 *
 * 1. **La croix est retenue** (`markPaywallDismissed`) : le tableau de bord ne rouvre pas la
 *    même offre une seconde plus tard.
 * 2. **Le cadeau tombe** (`paywallClosed`) : le drapeau est posé ici, et c'est l'hôte du
 *    cadeau, monté avec l'app, qui l'ouvre à l'arrivée - exactement comme après l'offre du
 *    tableau de bord.
 * 3. **Les réponses ont fini de traverser** : on attend le déversement lancé à l'arrivée avant
 *    d'ouvrir l'app, sinon l'app le relancerait de son côté et écrirait tout deux fois.
 *
 * Les prix sont ceux de `PaywallCard`, dans la devise du pays du profil - ou de celui qu'on
 * vient de répondre, quand le profil ne l'a pas encore reçu (un retour d'Apple ou de Google
 * arrive ici avant que les réponses n'aient traversé).
 */
export function OnboardingOffer({ country }: { country: string | null }) {
  const { t } = useI18n();
  const router = useRouter();
  const { answers } = useOnboarding();
  const saved = useRef<Promise<unknown> | null>(null);
  const [open, setOpen] = useState(true);
  const [leaving, setLeaving] = useState(false);

  useEffect(() => {
    // L'app se précharge **après** le déversement : avant, elle se rendrait sans la leçon de
    // démonstration ni le profil qu'on vient d'écrire.
    saved.current = persistStoredAnswers()
      .catch(() => undefined)
      .then(() => prefetchStep(router, "/app"));
  }, [router]);

  const enter = useCallback(async () => {
    if (leaving) return;
    setLeaving(true);
    await saved.current;
    router.replace("/app" as Route);
  }, [leaving, router]);

  const close = useCallback(() => {
    markPaywallDismissed();
    setOpen(false);
    // Refermé sans achat, le paywall fait tomber le cadeau (`DiscountOffer.paywallClosed` sur
    // l'iPhone, `GiftOffer` sur Android). L'achat, lui, part chez Stripe et ne revient pas ici.
    // Le compte vient d'être créé : il n'est pas abonné, sinon la page l'aurait fait entrer.
    paywallClosed(false);
    void enter();
  }, [enter]);

  return (
    <PresentmentProvider country={country ?? answers.country ?? null}>
      {/* Mika fait la fête sur le bord de la carte (l'habillage) : il n'est pas deux fois là. */}
      <div className="flex min-h-0 flex-1 flex-col items-center justify-center px-6 pb-10 pt-6 text-center">
        <span aria-hidden className="emoji text-[56px] leading-none">
          🎉
        </span>
        <h1 className="mt-5 text-balance text-[27px] font-extrabold leading-[1.1] tracking-tight-title text-ink sm:text-[31px]">
          {t("onboarding.accountReady")}
        </h1>
        <button
          type="button"
          onClick={() => void enter()}
          disabled={leaving}
          className="lp-cta mt-8 inline-flex h-14 items-center justify-center gap-2.5 rounded-[18px] bg-accent px-8 text-[16px] font-extrabold text-on-ink disabled:opacity-70"
        >
          {t("onboarding.openMicabo")}
        </button>
      </div>

      {open ? <PaywallCard startAt="social" onClose={close} surface="onboarding" /> : null}
    </PresentmentProvider>
  );
}
