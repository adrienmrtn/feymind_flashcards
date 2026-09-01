"use client";

import { useEffect, useId, useState } from "react";
import type { Route } from "next";
import { usePathname, useRouter, useSearchParams } from "next/navigation";

import { PaywallOffer } from "@/components/app/PaywallOffer";
import { isOfferClaimed } from "@/lib/discount";
import {
  isPaywallDismissed,
  isPaywallPending,
  markPaywallDismissed,
  persistStoredAnswers,
  shouldOpenPaywall,
} from "@/lib/onboarding/persist";
import { PAYWALL_EVENT } from "@/lib/paywall";

/**
 * Le paywall, **posé sur le tableau de bord**.
 *
 * Un écran, pas une série : ce que Pro ouvre, les deux formules, le bouton.
 * L'annuel est coché, avec trois jours d'essai. L'hebdomadaire n'en a pas.
 * Le tarif discount n'est pas sur cet écran.
 *
 * `isPaid` - pas `isPro`. Sans ça, tout le monde sans ligne d'abonnement est
 * traité comme Pro, et cette carte ne s'ouvre jamais.
 */

export function PaywallHost({ isPaid }: { isPaid: boolean }) {
  const params = useSearchParams();
  const pathname = usePathname();
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const debugReplay = params.get("debug") === "paywall";

  useEffect(() => {
    function onRequest() {
      if (isPaid && !debugReplay) return;
      setOpen(true);
    }
    window.addEventListener(PAYWALL_EVENT, onRequest);
    return () => window.removeEventListener(PAYWALL_EVENT, onRequest);
  }, [debugReplay, isPaid]);

  useEffect(() => {
    if (isPaid && !debugReplay) {
      setOpen(false);
      return;
    }

    let cancelled = false;
    let timer = 0;

    async function decide() {
      await persistStoredAnswers();
      if (cancelled) return;

      const force = params.get("offre") === "1";
      const welcome = params.get("bienvenue") === "1";
      const pending = isPaywallPending();
      const dismissed = isPaywallDismissed();
      const onHome = pathname === "/app";

      if (
        !shouldOpenPaywall({
          isPaid,
          force,
          welcome,
          pending,
          dismissed,
          onHome,
          debug: debugReplay,
        })
      ) {
        return;
      }

      const delay = force || debugReplay ? 0 : 980;
      timer = window.setTimeout(() => {
        if (cancelled || isOfferClaimed()) return;
        setOpen(true);
      }, delay);
    }

    void decide();
    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, [debugReplay, isPaid, params, pathname]);

  function close() {
    markPaywallDismissed();
    setOpen(false);
    if (params.get("bienvenue") || params.get("offre") || params.get("debug")) {
      router.replace(pathname as Route);
    }
  }

  if (!open) return null;
  return <PaywallCard key={debugReplay ? "debug-paywall" : "paywall"} onClose={close} />;
}

export function PaywallCard({ onClose }: { onClose: () => void }) {
  const titleId = useId();

  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      if (event.key !== "Escape") return;
      event.preventDefault();
      onClose();
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center p-3 sm:items-center sm:p-6">
      <button
        type="button"
        aria-label="Fermer l'offre"
        onClick={onClose}
        className="paywall-veil absolute inset-0 bg-ink/45 backdrop-blur-[8px]"
      />

      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        className="paywall-card relative flex max-h-[min(780px,92svh)] w-full max-w-[420px] flex-col overflow-hidden rounded-[28px] bg-surface shadow-[0_28px_90px_-20px_rgba(25,23,20,0.5)]"
      >
        <div className="flex items-center px-5 pt-4">
          <button
            type="button"
            aria-label="Fermer"
            onClick={onClose}
            className="pressable -ml-1 flex h-9 w-9 items-center justify-center rounded-full text-ink-tertiary hover:bg-canvas"
          >
            <svg aria-hidden viewBox="0 0 20 20" className="h-5 w-5">
              <path
                d="M5 5l10 10M15 5L5 15"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinecap="round"
              />
            </svg>
          </button>
        </div>

        <PaywallOffer headingId={titleId} />
      </div>
    </div>
  );
}
