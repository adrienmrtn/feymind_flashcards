"use client";

import { useEffect, useId, useRef, useState, type RefObject } from "react";
import { useRouter } from "next/navigation";
import { ThinkingOrb } from "thinking-orbs";

import { entitlement, pricing } from "@micabo/core";

import { startCheckout } from "@/lib/actions/checkout";

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
  const [chosen, setChosen] = useState<pricing.PlanKind>("yearly");
  const [pending, setPending] = useState(false);
  const [checkout, setCheckout] = useState<string | null>(null);
  const dialogRef = useRef<HTMLDivElement>(null);

  const plans = pricing.offers();
  const selected = pricing.planFor(chosen);

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

  async function subscribe() {
    setPending(true);
    setCheckout(null);
    const result = await startCheckout(chosen);
    setPending(false);
    if (result.status === "redirect" && result.url) {
      window.location.href = result.url;
      return;
    }
    if (result.status === "already") {
      setCheckout("Vous êtes déjà abonné.");
      router.refresh();
      return;
    }
    setCheckout(result.message ?? "L'abonnement n'est pas encore ouvert.");
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

          <div className="min-h-0 flex-1 overflow-y-auto px-6 pb-2">
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
                className="mt-5 text-[26px] font-bold leading-[1.15] tracking-tight-title text-ink"
              >
                Tes {reviewedCount} cartes gratuites sont faites.
              </h2>
              <p className="mt-3 text-[14.5px] leading-relaxed text-ink-secondary">
                La session s&apos;arrête là. Micabo Pro la laisse aller jusqu&apos;au
                bout, tous les jours, sur tous tes cours.
              </p>
            </div>

            <div className="mt-6 space-y-2.5">
              {plans.map((plan) => {
                const isSelected = chosen === plan.kind;
                const monthly = pricing.monthlyEquivalent(plan);
                const trial = pricing.hasTrial(plan);
                return (
                  <button
                    key={plan.productId}
                    type="button"
                    onClick={() => setChosen(plan.kind)}
                    className={`pressable flex w-full items-center justify-between gap-4 rounded-group px-5 py-4 text-left transition-colors duration-hover ${
                      isSelected ? "bg-ink text-on-ink" : "bg-canvas"
                    }`}
                  >
                    <div>
                      <p className="flex flex-wrap items-center gap-2 text-[15px] font-semibold">
                        {plan.title}
                        {trial ? (
                          <span className="rounded-pill bg-accent-vivid px-2 py-0.5 text-[10.5px] font-bold text-ink">
                            {plan.trialDays} jours offerts
                          </span>
                        ) : null}
                      </p>
                      <p
                        className={`mt-0.5 text-[13px] ${
                          isSelected ? "text-on-ink-muted" : "text-ink-tertiary"
                        }`}
                      >
                        {plan.kind === "yearly"
                          ? `${pricing.priceText(plan.price)} / an · essai de ${plan.trialDays} jours`
                          : "sans essai gratuit"}
                      </p>
                    </div>
                    <div className="shrink-0 text-right">
                      <p className="numeral text-[22px] font-bold leading-none">
                        {monthly ?? pricing.priceText(plan.price)}
                      </p>
                      <p
                        className={`mt-1 text-[11.5px] ${
                          isSelected ? "text-on-ink-muted" : "text-ink-tertiary"
                        }`}
                      >
                        {monthly ? "/ mois" : "/ semaine"}
                      </p>
                    </div>
                  </button>
                );
              })}
            </div>
          </div>

          <div className="px-6 pb-6 pt-3">
            <button
              type="button"
              onClick={() => void subscribe()}
              disabled={pending}
              className="pressable shiny flex h-14 w-full items-center justify-center gap-2 rounded-button bg-ink text-[16px] font-semibold text-on-ink disabled:opacity-70"
            >
              {pending ? <ThinkingOrb state="connecting" size={20} theme="dark" /> : null}
              {pricing.hasTrial(selected)
                ? `Essayer ${selected.trialDays} jours`
                : "S'abonner"}
            </button>
            <button
              type="button"
              onClick={leave}
              className="pressable mt-2.5 flex h-12 w-full items-center justify-center rounded-button text-[15px] font-semibold text-ink-secondary hover:bg-canvas"
            >
              Revenir à l&apos;accueil
            </button>
            {checkout ? (
              <p
                className="mt-3 rounded-button bg-canvas px-4 py-3 text-[13.5px] text-ink-secondary"
                role="status"
              >
                {checkout}
              </p>
            ) : (
              <p className="mt-3 text-center text-[12.5px] text-ink-tertiary">
                {pricing.hasTrial(selected)
                  ? `Aucun paiement aujourd'hui. Puis ${pricing.priceText(pricing.YEARLY.price)} / an.`
                  : `${pricing.priceText(pricing.WEEKLY.price)} / semaine, dès maintenant.`}
              </p>
            )}
          </div>
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
        className="pressable shiny mt-6 flex h-12 w-full items-center justify-center rounded-button bg-ink text-[15px] font-semibold text-on-ink"
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
