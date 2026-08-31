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
 * Une minuterie, un seul instant d'origine — voir `@micabo/core/discount`.
 * Le pop-up et la pastille montrent les mêmes vingt-quatre heures.
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
 * **Le même décompte, au centième.**
 *
 * Soixante millisecondes entre deux images : assez pour que les centièmes
 * défilent, pas assez pour que ça coûte quelque chose. Le battement s'arrête à
 * zéro — une minuterie terminée qui continue de réveiller le navigateur est du
 * travail que personne ne regarde.
 */
function usePreciseCountdown(startedAt: number, span: number): number {
  const [left, setLeft] = useState(() =>
    discount.remainingMillis(startedAt, Date.now(), span),
  );

  useEffect(() => {
    let tick = 0;

    function beat() {
      const value = discount.remainingMillis(startedAt, Date.now(), span);
      setLeft(value);
      if (value <= 0) window.clearInterval(tick);
    }

    beat();
    tick = window.setInterval(beat, 60);
    return () => window.clearInterval(tick);
  }, [span, startedAt]);

  return left;
}

/**
 * **La carte de l'offre.** Une minuterie, un pourcentage, un prix, un bouton.
 *
 * Ce qu'elle ne fait pas est ce qui la fait marcher. Pas de liste d'avantages,
 * pas d'illustration, pas de sur-titre : l'offre a déjà été annoncée, et ce
 * qu'on doit lire pour décider tient en quatre lignes. Une carte d'offre qui
 * argumente encore est une carte qui n'a pas confiance en son prix.
 *
 * Le fond va du bleu ciel au blanc, du haut vers le bas : la minuterie et le
 * pourcentage sont dans la couleur, le prix et le bouton sont sur le blanc, là
 * où on les lit sans effort.
 */
export function DiscountCard({
  startedAt,
  onClose,
}: {
  startedAt: number;
  onClose: () => void;
}) {
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
      setFailure("Tu es déjà abonné.");
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
        className="paywall-veil absolute inset-0 bg-ink/45 backdrop-blur-[10px]"
      />

      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="cadeau-title"
        className="paywall-card relative max-h-[94svh] w-full max-w-[500px] overflow-y-auto rounded-[28px] bg-gradient-to-b from-offer-wash via-offer-wash-soft to-surface px-5 pb-6 pt-11 shadow-[0_34px_110px_-24px_rgba(11,143,220,0.55)] sm:px-7"
      >
        <button
          type="button"
          aria-label="Fermer"
          onClick={onClose}
          className="pressable absolute right-3 top-3 flex h-10 w-10 items-center justify-center rounded-full text-offer-sky"
        >
          <svg aria-hidden viewBox="0 0 20 20" className="h-[22px] w-[22px]">
            <path
              d="M5 5l10 10M15 5L5 15"
              fill="none"
              stroke="currentColor"
              strokeWidth="2.2"
              strokeLinecap="round"
            />
          </svg>
        </button>

        <div className="flex flex-col items-center text-center">
          <UrgencyPill startedAt={startedAt} />

          <h2
            id="cadeau-title"
            className="mt-5 text-[28px] font-bold leading-[1.08] tracking-tight-title text-ink sm:text-[36px]"
          >
            <span className="text-offer-sky">{saved}&nbsp;%</span> de moins
            <br />
            Révise plus vite avec Pro
          </h2>

          <div className="mt-6 flex w-full items-center gap-4 rounded-[22px] bg-surface px-4 py-4 text-left shadow-[0_14px_34px_-18px_rgba(11,143,220,0.55)] sm:px-5">
            <SaleSeal percent={saved} />

            <div className="min-w-0">
              <p className="text-[14.5px] font-semibold text-offer-sky">{plan.title}</p>

              <p className="mt-0.5 flex flex-wrap items-baseline gap-x-2">
                <span className="numeral text-[26px] font-bold leading-none text-ink">
                  {monthly}
                </span>
                <span className="text-[15px] font-medium text-ink-secondary">par mois</span>
              </p>

              <s className="mt-1 block text-[15.5px] font-medium text-ink-tertiary">
                {pricing.priceText(full.price)}
              </s>
            </div>
          </div>

          <button
            type="button"
            onClick={() => void subscribe()}
            disabled={pending}
            className="pressable shiny mt-5 flex h-[58px] w-full items-center justify-center gap-2 rounded-[16px] bg-offer-sky text-[17px] font-semibold text-white disabled:opacity-70"
          >
            {pending ? <ThinkingOrb state="connecting" size={20} theme="dark" /> : null}
            Commencer avec {saved}&nbsp;% de moins
          </button>

          {failure ? (
            <p
              role="status"
              className="mt-3 w-full rounded-button bg-negative-soft px-4 py-3 text-[13.5px] text-negative"
            >
              {failure}
            </p>
          ) : (
            // Le mensuel vend, l'annuel engage : le montant réellement prélevé est écrit
            // sous le bouton, jamais ailleurs qu'à côté de lui.
            <p className="mt-3 text-[12.5px] text-ink-tertiary">
              {pricing.priceText(plan.price)} facturés une fois par an, résiliable à tout
              moment.
            </p>
          )}
        </div>
      </div>
    </div>
  );
}

/**
 * La minuterie de l'offre, en pastille violette.
 *
 * Elle vit dans son propre composant : elle se redessine dix-sept fois par
 * seconde, et le reste de la carte n'a aucune raison de la suivre. Elle compte
 * la même fenêtre que la pastille — vingt-quatre heures — pour que refermer
 * puis rouvrir ne change pas le temps affiché.
 */
function UrgencyPill({ startedAt }: { startedAt: number }) {
  const left = usePreciseCountdown(startedAt, discount.windowSeconds);
  const over = left <= 0;

  return (
    <p
      className="inline-flex items-baseline gap-2 rounded-pill bg-offer-urgency px-4 py-2 text-white"
      role="timer"
      aria-label={over ? "offre terminée" : `Offre réservée, ${discount.countdownLabel(Math.floor(left / 1000))}`}
    >
      {/* La police des nombres, comme partout dans Micabo, et des chiffres de largeur fixe :
          un décompte qui change de largeur à chaque centième ferait trembler la pastille. */}
      <span className="font-number text-[15px] font-semibold tabular-nums" aria-hidden>
        {discount.preciseCountdown(left)}
      </span>
      <span className="text-[13px] font-medium text-white/85">
        {over ? "terminé" : "restant"}
      </span>
    </p>
  );
}

/**
 * Le sceau de la remise : un disque à douze festons.
 *
 * Festonné et non rond, parce qu'un rond bleu avec un nombre dedans est une
 * pastille d'état — la même forme que « 4 à réviser ». Les festons disent
 * « étiquette collée sur un prix », ce qui est exactement ce que c'est.
 */
function SaleSeal({ percent }: { percent: number }) {
  return (
    <span
      aria-hidden
      className="relative grid h-[68px] w-[68px] shrink-0 place-items-center"
    >
      <svg viewBox="0 0 100 100" className="absolute inset-0 h-full w-full">
        <defs>
          <linearGradient id="offer-seal" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="var(--color-offer-sky)" />
            <stop offset="100%" stopColor="var(--color-offer-sky-deep)" />
          </linearGradient>
        </defs>
        <path d={SEAL_PATH} fill="url(#offer-seal)" />
      </svg>

      <span className="relative flex flex-col items-center leading-none text-white">
        <span className="text-[9.5px] font-semibold">Remise</span>
        <span className="mt-0.5 text-[20px] font-bold">
          {percent}
          <span className="align-top text-[10px]">%</span>
        </span>
      </span>
    </span>
  );
}

/**
 * Le contour du sceau, calculé une fois pour toutes.
 *
 * Le sommet d'une quadratique est en `(p0 + 2c + p1) / 4` : le point de contrôle
 * se déduit donc de la crête voulue, et non l'inverse. Sans ce calcul, poser les
 * contrôles « à vue » donne des festons d'amplitudes différentes.
 */
const SEAL_PATH = scallopedDisc(12, 41, 7);

function scallopedDisc(scallops: number, radius: number, bump: number): string {
  const center = 50;
  const step = (Math.PI * 2) / scallops;
  const round = (value: number) => Math.round(value * 100) / 100;
  const point = (angle: number, distance: number) =>
    [center + distance * Math.cos(angle), center + distance * Math.sin(angle)] as const;

  let path = "";

  for (let index = 0; index < scallops; index += 1) {
    const from = point(index * step, radius);
    const to = point((index + 1) * step, radius);
    const crest = point((index + 0.5) * step, radius + bump);
    const control = [
      2 * crest[0] - (from[0] + to[0]) / 2,
      2 * crest[1] - (from[1] + to[1]) / 2,
    ] as const;

    if (index === 0) path += `M${round(from[0])} ${round(from[1])}`;
    path += `Q${round(control[0])} ${round(control[1])} ${round(to[0])} ${round(to[1])}`;
  }

  return `${path}Z`;
}

/**
 * La pastille, quand la carte s'est refermée.
 *
 * Elle porte le décompte des vingt-quatre heures et rien d'autre : un clic
 * rouvre l'offre. En bas à droite, au-dessus de la page, hors du flux — elle ne
 * doit pas pousser l'étagère vers le bas à chaque chargement.
 *
 * Elle compte en secondes, pas en centièmes : sur vingt-quatre heures, des
 * centièmes qui défilent dans un coin de l'écran sont un clignotant.
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
      aria-label={`Rouvrir l'offre, ${discount.countdownLabel(left)}`}
      className="pressable fixed bottom-5 right-5 z-40 flex items-center gap-2.5 rounded-pill bg-offer-sky px-4 py-3 text-white shadow-[0_16px_40px_-12px_rgba(11,143,220,0.6)]"
    >
      <span aria-hidden className="text-white">
        <GiftGlyph />
      </span>
      <span className="text-left">
        <span className="block text-[11px] font-semibold uppercase tracking-[0.08em] text-white/80">
          Ton offre
        </span>
        <span className="block font-number text-[15px] font-bold tabular-nums" aria-hidden>
          {discount.countdown(left)}
        </span>
      </span>
    </button>
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
