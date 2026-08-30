"use client";

import { useCallback, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { ThinkingOrb } from "thinking-orbs";

import { discount, pricing } from "@micabo/core";

import { startCheckout } from "@/lib/actions/checkout";
import {
  claimOffer,
  isDiscountSeen,
  markDiscountSeen,
  readDiscountStart,
  releaseOffer,
  shouldOpenDiscount,
  shouldShowDiscountBadge,
  startDiscount,
} from "@/lib/discount";

/**
 * **L'offre cadeau du web**, et sa pastille.
 *
 * Elle se présente une fois, dès le premier cours importé, en grand. Refermée,
 * elle ne disparaît pas : une pastille garde le décompte des vingt-quatre
 * heures et la rouvre d'un clic. C'est la différence entre une offre qu'on
 * refuse et une offre qu'on remet à plus tard, et seule la seconde se vend.
 *
 * Deux minuteries, un seul instant d'origine — voir `@micabo/core/discount`.
 * Le paywall en montre une heure, la pastille vingt-quatre.
 *
 * `isPaid`, pas `isPro` : sans ligne d'abonnement, tout le monde serait traité
 * comme abonné et ce cadeau ne s'ouvrirait jamais.
 */
export function DiscountHost({
  isPaid,
  courseCount,
}: {
  isPaid: boolean;
  courseCount: number;
}) {
  const params = useSearchParams();
  const debug = params.get("debug") === "cadeau";

  const [open, setOpen] = useState(false);
  const [startedAt, setStartedAt] = useState<number | null>(null);
  const [seen, setSeen] = useState(false);

  useEffect(() => {
    setStartedAt(readDiscountStart());
    setSeen(isDiscountSeen());
  }, []);

  useEffect(() => {
    if (
      !shouldOpenDiscount({
        isPaid,
        courseCount,
        seen: isDiscountSeen(),
        startedAt: readDiscountStart(),
        now: Date.now(),
        debug,
      })
    ) {
      return;
    }

    // L'instant se pose à l'ouverture, pas au premier cours : le décompte doit
    // commencer quand l'offre a été vue, sinon il a déjà couru sans témoin.
    claimOffer();
    setStartedAt(startDiscount());
    setOpen(true);
  }, [courseCount, debug, isPaid]);

  const close = useCallback(() => {
    markDiscountSeen();
    releaseOffer();
    setSeen(true);
    setOpen(false);
  }, []);

  const reopen = useCallback(() => {
    claimOffer();
    setStartedAt(startDiscount());
    setOpen(true);
  }, []);

  if (open && startedAt !== null) {
    return <DiscountCard startedAt={startedAt} onClose={close} />;
  }

  if (
    shouldShowDiscountBadge({ isPaid, courseCount, seen, startedAt, now: Date.now() })
  ) {
    return <DiscountBadge startedAt={startedAt as number} onOpen={reopen} />;
  }

  return null;
}

/** Une seconde qui tombe, et rien d'autre. Le rendu suit, le calcul est ailleurs. */
function useCountdown(startedAt: number, span: number): number {
  const [left, setLeft] = useState(() => discount.remaining(startedAt, Date.now(), span));

  useEffect(() => {
    setLeft(discount.remaining(startedAt, Date.now(), span));
    const tick = window.setInterval(() => {
      setLeft(discount.remaining(startedAt, Date.now(), span));
    }, 1000);
    return () => window.clearInterval(tick);
  }, [span, startedAt]);

  return left;
}

/**
 * La grande pop-up : le cadeau, le décompte, le prix, un bouton.
 *
 * Elle est plus large que le paywall ordinaire — c'est une offre, pas un
 * parcours en quatre étapes — et elle tient en une page : ce qu'on doit lire
 * pour décider est au-dessus du bouton, jamais sous un défilement.
 */
export function DiscountCard({
  startedAt,
  onClose,
}: {
  startedAt: number;
  onClose: () => void;
}) {
  const left = useCountdown(startedAt, discount.urgencySeconds);
  const plan = pricing.DISCOUNT_YEARLY;
  const full = pricing.DISCOUNT_REFERENCE;
  const monthly = pricing.monthlyEquivalent(plan);
  const saved = pricing.discountSavingsPercent();

  const [pending, setPending] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);

  async function subscribe() {
    setPending(true);
    setFailure(null);
    const result = await startCheckout("yearly_discount");
    setPending(false);

    if (result.status === "redirect" && result.url) {
      window.location.href = result.url;
      return;
    }
    if (result.status === "already") {
      setFailure("Vous êtes déjà abonné.");
      return;
    }
    setFailure(result.message ?? "L'abonnement n'est pas encore ouvert.");
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center p-3 sm:items-center sm:p-6">
      <button
        type="button"
        aria-label="Fermer l'offre"
        onClick={onClose}
        className="paywall-veil absolute inset-0 bg-ink/55 backdrop-blur-[10px]"
      />

      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="cadeau-title"
        className="paywall-card relative flex max-h-[min(820px,94svh)] w-full max-w-[620px] flex-col overflow-hidden rounded-[28px] bg-info text-on-ink shadow-[0_34px_110px_-24px_rgba(25,23,20,0.65)]"
      >
        <button
          type="button"
          aria-label="Fermer"
          onClick={onClose}
          className="pressable absolute right-4 top-4 z-10 flex h-9 w-9 items-center justify-center rounded-full bg-on-ink/15 text-on-ink"
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

        <div className="min-h-0 flex-1 overflow-y-auto px-6 pb-2 pt-9 sm:px-10 sm:pt-11">
          <div className="flex flex-col items-center text-center">
            <span aria-hidden className="text-on-ink">
              <GiftBox />
            </span>

            <p className="eyebrow mt-5 text-on-ink/75">Cadeau de bienvenue</p>
            <h2
              id="cadeau-title"
              className="mt-2 text-[28px] font-bold leading-[1.12] tracking-tight-title sm:text-[32px]"
            >
              Votre premier cours vous ouvre&nbsp;Pro à&nbsp;{saved}&nbsp;% de moins.
            </h2>

            <Countdown seconds={left} />

            <div className="mt-7 flex flex-wrap items-end justify-center gap-x-4 gap-y-1">
              <span className="numeral text-[52px] font-bold leading-none tracking-display sm:text-[60px]">
                {monthly}
              </span>
              <span className="pb-2 text-[17px] font-semibold text-on-ink/80">/ mois</span>
            </div>
            <p className="mt-3 text-[14.5px] text-on-ink/80">
              <s className="text-on-ink/60">{pricing.priceText(full.price)} / an</s>
              <span className="mx-2" aria-hidden>
                →
              </span>
              <strong className="font-semibold text-on-ink">
                {pricing.priceText(plan.price)} / an
              </strong>
            </p>

            <ul className="mt-7 w-full space-y-2.5 text-left">
              {PERKS.map((perk) => (
                <li
                  key={perk}
                  className="flex items-start gap-3 rounded-button bg-on-ink/10 px-4 py-3 text-[14.5px] font-medium"
                >
                  <span aria-hidden className="mt-0.5 shrink-0 text-on-ink">
                    <Check />
                  </span>
                  {perk}
                </li>
              ))}
            </ul>
          </div>
        </div>

        <div className="px-6 pb-6 pt-4 sm:px-10">
          <button
            type="button"
            onClick={() => void subscribe()}
            disabled={pending}
            className="pressable shiny flex h-14 w-full items-center justify-center gap-2 rounded-button bg-on-ink text-[16px] font-semibold text-ink disabled:opacity-70"
          >
            {pending ? <ThinkingOrb state="connecting" size={20} theme="light" /> : null}
            Profiter du cadeau
          </button>

          {failure ? (
            <p
              role="status"
              className="mt-3 rounded-button bg-on-ink/10 px-4 py-3 text-[13.5px] text-on-ink"
            >
              {failure}
            </p>
          ) : (
            <p className="mt-3 text-center text-[12.5px] text-on-ink/70">
              {pricing.priceText(plan.price)} facturés une fois par an. Sans essai, résiliable
              à tout moment.
            </p>
          )}
        </div>
      </div>
    </div>
  );
}

/** Le décompte de l'heure, en gros, au-dessus du prix. */
function Countdown({ seconds }: { seconds: number }) {
  const over = seconds <= 0;
  return (
    <p
      className="mt-6 inline-flex items-center gap-2 rounded-pill bg-on-ink/15 px-4 py-2"
      role="timer"
      aria-label={
        over ? "offre terminée" : `Offre réservée, ${discount.countdownLabel(seconds)}`
      }
    >
      <span aria-hidden className="text-on-ink/80">
        <Clock />
      </span>
      <span className="numeral text-[19px] font-bold" aria-hidden>
        {discount.countdown(seconds)}
      </span>
      <span className="text-[13px] font-medium text-on-ink/80">
        {over ? "dernier appel" : "réservé pour vous"}
      </span>
    </p>
  );
}

/**
 * La pastille, quand la pop-up s'est refermée.
 *
 * Elle porte le décompte des vingt-quatre heures et rien d'autre : un clic
 * rouvre l'offre. En bas à droite, au-dessus de la page, hors du flux — elle ne
 * doit pas pousser l'étagère vers le bas à chaque chargement.
 */
export function DiscountBadge({
  startedAt,
  onOpen,
}: {
  startedAt: number;
  onOpen: () => void;
}) {
  const left = useCountdown(startedAt, discount.windowSeconds);
  if (left <= 0) return null;

  return (
    <button
      type="button"
      onClick={onOpen}
      aria-label={`Rouvrir le cadeau, ${discount.countdownLabel(left)}`}
      className="pressable fixed bottom-5 right-5 z-40 flex items-center gap-2.5 rounded-pill bg-info px-4 py-3 text-on-ink shadow-[0_16px_40px_-12px_rgba(25,23,20,0.55)]"
    >
      <span aria-hidden className="text-on-ink">
        <GiftGlyph />
      </span>
      <span className="text-left">
        <span className="block text-[11px] font-semibold uppercase tracking-[0.08em] text-on-ink/75">
          Votre cadeau
        </span>
        <span className="numeral block text-[15px] font-bold" aria-hidden>
          {discount.countdown(left)}
        </span>
      </span>
    </button>
  );
}

const PERKS = [
  "Cours illimités, et la fiche entière",
  "Sessions sans coupure à la cinquième carte",
  "Entraînement libre, quand l'examen approche",
] as const;

function GiftBox() {
  return (
    <svg aria-hidden viewBox="0 0 96 96" className="h-[76px] w-[76px]">
      <rect x="16" y="38" width="64" height="44" rx="8" fill="currentColor" />
      <rect x="16" y="28" width="64" height="16" rx="6" fill="currentColor" opacity="0.85" />
      <rect x="44" y="28" width="8" height="54" fill="currentColor" opacity="0.45" />
      <path
        d="M48 28c-8-12-20-12-20-2 0 8 12 10 20 10 8 0 20-2 20-10 0-10-12-10-20 2z"
        fill="currentColor"
        opacity="0.7"
      />
    </svg>
  );
}

function GiftGlyph() {
  return (
    <svg aria-hidden viewBox="0 0 24 24" className="h-6 w-6">
      <rect x="4" y="10" width="16" height="10" rx="2" fill="currentColor" />
      <rect x="3" y="7" width="18" height="4.5" rx="1.6" fill="currentColor" opacity="0.85" />
      <rect x="10.8" y="7" width="2.4" height="13" fill="currentColor" opacity="0.4" />
      <path
        d="M12 7c-2-3.2-5.2-3.2-5.2-.6 0 2.1 3.2 2.6 5.2 2.6s5.2-.5 5.2-2.6C17.2 3.8 14 3.8 12 7z"
        fill="currentColor"
        opacity="0.7"
      />
    </svg>
  );
}

function Clock() {
  return (
    <svg aria-hidden viewBox="0 0 20 20" className="h-4 w-4">
      <circle cx="10" cy="10" r="7.2" fill="none" stroke="currentColor" strokeWidth="1.7" />
      <path
        d="M10 6v4.3l2.8 1.7"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.7"
        strokeLinecap="round"
      />
    </svg>
  );
}

function Check() {
  return (
    <svg aria-hidden viewBox="0 0 20 20" className="h-[18px] w-[18px]">
      <path
        d="M4.5 10.5l3.4 3.4 7.6-8"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
