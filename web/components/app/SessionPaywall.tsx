"use client";

import { useEffect, useId, useRef, useState, type RefObject } from "react";
import { useRouter } from "next/navigation";

import { entitlement } from "@micabo/core";

import { PaywallOffer } from "@/components/app/PaywallOffer";

/**
 * Le paywall qui **coupe une session au bout de cinq cartes**.
 *
 * Comme sur iOS : il s'ouvre par-dessus la carte suivante, pas à la
 * place de la session. S'abonner, ou rentrer. La croix demande
 * confirmation — ailleurs elle referme un écran, ici elle abandonne
 * une session commencée.
 */
export function SessionPaywall({ reviewedCount }: { reviewedCount: number }) {
  const router = useRouter();
  const titleId = useId();
  const [abandoning, setAbandoning] = useState(false);
  const dialogRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    dialogRef.current?.focus();
  }, [abandoning]);

  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      if (event.key !== "Escape") return;
      event.preventDefault();
      event.stopPropagation();
      setAbandoning((open) => !open);
    }
    window.addEventListener("keydown", onKey, true);
    return () => window.removeEventListener("keydown", onKey, true);
  }, []);

  function leave() {
    router.push("/app");
    router.refresh();
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center p-3 sm:items-center sm:p-6">
      <div className="paywall-veil absolute inset-0 bg-ink/45 backdrop-blur-[8px]" />

      {abandoning ? (
        <AbandonCard
          titleId={titleId}
          dialogRef={dialogRef}
          onReturn={() => setAbandoning(false)}
          onAbandon={leave}
        />
      ) : (
        <div
          ref={dialogRef}
          role="dialog"
          aria-modal="true"
          aria-labelledby={titleId}
          tabIndex={-1}
          className="paywall-card relative flex max-h-[min(760px,92svh)] w-full max-w-[440px] flex-col overflow-hidden rounded-[28px] bg-surface shadow-[0_28px_90px_-20px_rgba(25,23,20,0.5)] outline-none"
        >
          <div className="flex items-center justify-end px-5 pt-4">
            <button
              type="button"
              aria-label="Fermer"
              onClick={() => setAbandoning(true)}
              className="pressable -mr-1 flex h-9 w-9 items-center justify-center rounded-full text-ink-tertiary hover:bg-canvas"
            >
              <CloseIcon />
            </button>
          </div>

          <div className="px-6 pb-1">
            <div className="flex flex-col items-center text-center">
              <p className="inline-flex items-center gap-2 rounded-pill bg-accent-soft px-3.5 py-1.5 text-[13px] font-semibold text-accent">
                <CheckIcon />
                <span className="numeral">
                  {reviewedCount} / {entitlement.FREE_TIER.cardsPerSession} cartes
                  révisées
                </span>
              </p>
              <h2
                id={titleId}
                className="mt-4 text-[22px] font-bold leading-[1.15] tracking-tight-title text-ink"
              >
                Tes {reviewedCount} cartes gratuites sont faites.
              </h2>
            </div>
          </div>

          <PaywallOffer
            headingId={`${titleId}-offer`}
            onSubscribed={() => router.refresh()}
            extraAction={
              <button
                type="button"
                onClick={leave}
                className="pressable mt-2.5 flex h-12 w-full items-center justify-center rounded-button text-[15px] font-semibold text-ink-secondary hover:bg-canvas"
              >
                Revenir à l&apos;accueil
              </button>
            }
          />
        </div>
      )}
    </div>
  );
}

function AbandonCard({
  titleId,
  dialogRef,
  onReturn,
  onAbandon,
}: {
  titleId: string;
  dialogRef: RefObject<HTMLDivElement | null>;
  onReturn: () => void;
  onAbandon: () => void;
}) {
  return (
    <div
      ref={dialogRef}
      role="dialog"
      aria-modal="true"
      aria-labelledby={titleId}
      tabIndex={-1}
      className="relative w-full max-w-[400px] rounded-[28px] bg-surface px-6 py-7 text-center shadow-[0_28px_90px_-20px_rgba(25,23,20,0.5)] outline-none"
    >
      <span
        aria-hidden
        className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-caution-soft text-caution"
      >
        <WarnIcon />
      </span>
      <h2
        id={titleId}
        className="mt-5 text-[20px] font-bold leading-[1.2] tracking-tight-title text-ink"
      >
        Tu es sûr d&apos;abandonner ta progression ?
      </h2>
      <p className="mt-2.5 text-[14px] leading-relaxed text-ink-secondary">
        Les cartes déjà notées sont enregistrées. Les suivantes attendront ta
        prochaine session.
      </p>
      <button
        type="button"
        onClick={onReturn}
        className="pressable shiny mt-6 flex h-12 w-full items-center justify-center rounded-button bg-accent text-[15px] font-semibold text-on-ink"
      >
        Revenir
      </button>
      <button
        type="button"
        onClick={onAbandon}
        className="pressable mt-2 flex h-12 w-full items-center justify-center rounded-button text-[14.5px] font-semibold text-negative hover:bg-negative-soft"
      >
        Abandonner la session
      </button>
    </div>
  );
}

function CloseIcon() {
  return (
    <svg aria-hidden viewBox="0 0 20 20" className="h-5 w-5">
      <path
        d="M5 5l10 10M15 5L5 15"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
      />
    </svg>
  );
}

function CheckIcon() {
  return (
    <svg aria-hidden viewBox="0 0 20 20" className="h-3.5 w-3.5">
      <path
        d="M5 10.5l3.2 3.2L15 7"
        fill="none"
        stroke="currentColor"
        strokeWidth="2.2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function WarnIcon() {
  return (
    <svg aria-hidden viewBox="0 0 24 24" className="h-6 w-6">
      <path
        d="M12 8.5v5M12 16.4h.01"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
      />
      <path
        d="M11 4.8L2.8 18.4c-.4.7.1 1.6.9 1.6h16.6c.8 0 1.3-.9.9-1.6L12.9 4.8c-.4-.7-1.5-.7-1.9 0z"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinejoin="round"
      />
    </svg>
  );
}
