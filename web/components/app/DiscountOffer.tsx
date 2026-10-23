"use client";

import { useCallback, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { ThinkingOrb } from "thinking-orbs";

import { discount, pricing } from "@micabo/core";

import { Float } from "@/components/app/Float";
import { startCheckout } from "@/lib/actions/checkout";
import { trackCheckoutStart, trackPaywallView } from "@/lib/analytics/funnel";
import {
  DISCOUNT_EVENT,
  claimOffer,
  isDiscountSeen,
  markDiscountSeen,
  readDiscountStart,
  releaseOffer,
  requestDiscount,
  shouldShowDiscountBadge,
  startDiscount,
  takePendingGift,
  type DiscountRequest,
  type DiscountStage,
} from "@/lib/discount";
import { useI18n } from "@/lib/i18n/client";
import { usePresentment } from "@/lib/presentment";
import { requestTourRecheck } from "@/lib/tour/signal";

/**
 * **L'offre cadeau du web**, sa boîte à déballer et sa pastille. Jumeau de
 * `DiscountBadgeHost` + `DiscountFlowView` côté Swift.
 *
 * **Un paywall refermé sans achat fait tomber le cadeau** (`paywallClosed`) : une boîte qui
 * ne dit pas de prix, trois appuis pour l'ouvrir, puis le tarif réduit et rien qu'un prix.
 * Refermée, l'offre ne disparaît pas : une pastille garde le décompte des vingt-quatre heures
 * et rouvre le tarif d'un clic — on ne fait pas déballer deux fois. La rangée du profil
 * l'ouvre aussi (`requestDiscount("paywall")`).
 *
 * Une minuterie, un seul instant d'origine — voir `@micabo/core/discount`. L'instant se pose
 * au troisième appui, pas à la fermeture du paywall : un décompte qui a commencé sans témoin
 * est un décompte déjà perdu.
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

  const [presentation, setPresentation] = useState<DiscountStage | null>(null);
  const [startedAt, setStartedAt] = useState<number | null>(null);
  const [seen, setSeen] = useState(false);

  useEffect(() => {
    setStartedAt(readDiscountStart());
    setSeen(isDiscountSeen());
  }, []);

  /**
   * Le cadeau demandé par un paywall refermé, **une fois la carte repliée** : 700 ms, comme
   * `presentPendingGift` sur l'iPhone. Deux cartes qui se croisent ne se lisent pas, et le
   * drapeau `claimOffer` empêche le paywall différé de se poser par-dessus.
   */
  useEffect(() => {
    let timer = 0;
    function present() {
      window.clearTimeout(timer);
      if (isPaid && !debug) return;
      claimOffer();
      timer = window.setTimeout(() => setPresentation((current) => current ?? "gift"), 700);
    }

    if (debug || takePendingGift()) present();

    function onRequest(event: Event) {
      const stage = (event as CustomEvent<DiscountRequest>).detail?.stage ?? "gift";
      if (stage === "gift") {
        takePendingGift();
        present();
        return;
      }
      if (isPaid && !debug) return;
      // Le tarif, sans boîte : depuis la pastille ou le profil. L'ouvrir relance une fenêtre
      // si la précédente est finie (`startDiscount`), comme `DiscountFlowView(startsAtPaywall:)`.
      claimOffer();
      setStartedAt(startDiscount());
      setPresentation("paywall");
    }

    window.addEventListener(DISCOUNT_EVENT, onRequest);
    return () => {
      window.clearTimeout(timer);
      window.removeEventListener(DISCOUNT_EVENT, onRequest);
    };
  }, [debug, isPaid]);

  const close = useCallback(() => {
    // L'instant vient de `markDiscountSeen` : refermer le cadeau avant le troisième appui
    // démarre la fenêtre aussi, et la pastille a besoin de cet instant pour s'afficher.
    setStartedAt(markDiscountSeen());
    releaseOffer();
    setSeen(true);
    setPresentation(null);
    requestTourRecheck();
  }, []);

  const opened = useCallback(() => {
    setStartedAt(startDiscount());
    setPresentation("paywall");
  }, []);

  const reopen = useCallback(() => requestDiscount("paywall"), []);

  if (presentation === "gift") {
    return <DiscountGift onOpened={opened} onDismiss={close} />;
  }

  if (presentation === "paywall" && startedAt !== null) {
    return <DiscountCard onClose={close} />;
  }

  if (
    shouldShowDiscountBadge({ isPaid, courseCount, seen, startedAt, now: Date.now() })
  ) {
    return <DiscountBadge startedAt={startedAt as number} onOpen={reopen} />;
  }

  return null;
}

/**
 * **Le cadeau, en pop-up** : la carte, pas l'écran. `DiscountGiftStage` côté Swift.
 *
 * Chaque appui fait deux choses : la boîte encaisse le coup (elle s'écrase puis rebondit,
 * en penchant d'un côté puis de l'autre), et une pastille de plus se remplit sous elle. Au
 * troisième, la main passe au tarif — après une demi-seconde, le temps que la boîte s'ouvre.
 * Sans ces retours, appuyer trois fois sur une image ressemble à une image qui ne répond pas.
 */
export function DiscountGift({ onOpened, onDismiss }: { onOpened: () => void; onDismiss: () => void }) {
  const { t } = useI18n();
  const [taps, setTaps] = useState(0);
  const [squash, setSquash] = useState(false);
  const remaining = Math.max(0, discount.taps - taps);

  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      if (event.key !== "Escape") return;
      event.preventDefault();
      onDismiss();
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onDismiss]);

  useEffect(() => {
    if (!squash) return;
    const timer = window.setTimeout(() => setSquash(false), 130);
    return () => window.clearTimeout(timer);
  }, [squash, taps]);

  useEffect(() => {
    if (taps < discount.taps) return;
    const timer = window.setTimeout(onOpened, 500);
    return () => window.clearTimeout(timer);
  }, [onOpened, taps]);

  function tap() {
    if (taps >= discount.taps) return;
    setTaps((count) => count + 1);
    setSquash(true);
  }

  const wobble = squash ? (taps % 2 === 0 ? -5 : 5) : 0;
  const lift = Math.min(taps, discount.taps) * 4;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-6">
      <div aria-hidden className="paywall-veil absolute inset-0 bg-ink/40 backdrop-blur-[6px]" />

      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="cadeau-boite-title"
        className="paywall-card relative w-full max-w-[400px] rounded-[28px] bg-gradient-to-b from-offer-wash via-offer-wash-soft to-surface px-5 pb-6 pt-3 shadow-[0_34px_110px_-24px_rgba(11,143,220,0.55)]"
      >
        <div className="flex justify-end">
          <button
            type="button"
            aria-label={t("app.a11y.close")}
            onClick={onDismiss}
            className="pressable -mr-1 flex h-10 w-10 items-center justify-center rounded-full text-offer-sky"
          >
            <svg aria-hidden viewBox="0 0 20 20" className="h-[22px] w-[22px]">
              <path d="M5 5l10 10M15 5L5 15" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" />
            </svg>
          </button>
        </div>

        <div className="flex flex-col items-center text-center">
          <h2 id="cadeau-boite-title" className="px-2 text-[26px] font-bold leading-[1.12] tracking-tight-title text-ink">
            {t("app.paywall.giftTitle")}
          </h2>
          <p className="mt-2 px-2 text-[15px] text-ink-secondary">{t("app.paywall.giftBody")}</p>

          <button
            type="button"
            onClick={tap}
            aria-label={t("app.paywall.openGift")}
            aria-describedby="cadeau-boite-hint"
            className="mt-6 flex h-[176px] w-[176px] items-center justify-center rounded-[32px] text-offer-sky outline-none focus-visible:shadow-[0_0_0_3px_var(--color-offer-sky)]"
            style={{
              transform: `scale(${squash ? 0.9 : 1}) rotate(${wobble}deg)`,
              transition: "transform 220ms cubic-bezier(0.34, 1.56, 0.64, 1)",
            }}
          >
            <GiftBox lift={lift} open={taps >= discount.taps} />
          </button>
          <span id="cadeau-boite-hint" className="sr-only">
            {t("app.paywall.tapGiftHint", { n: discount.taps })}
          </span>

          <div className="mt-6 flex items-center gap-2" aria-hidden>
            {Array.from({ length: discount.taps }, (_, index) => (
              <span
                key={index}
                className="h-[9px] rounded-pill bg-offer-sky transition-all duration-200"
                style={{ width: index < taps ? 26 : 9, opacity: index < taps ? 1 : 0.25 }}
              />
            ))}
          </div>
          <p role="status" aria-live="polite" className="mt-3 text-[14px] font-semibold text-ink-secondary">
            {remaining === 0 ? t("app.paywall.giftOpening") : t("app.paywall.giftTapsLeft", { n: remaining })}
          </p>
        </div>
      </div>
    </div>
  );
}

/** La boîte : un corps, un couvercle qui remonte d'un cran à chaque appui, un nœud. */
function GiftBox({ lift, open }: { lift: number; open: boolean }) {
  return (
    <svg aria-hidden viewBox="0 0 120 120" className="h-[150px] w-[150px] overflow-visible">
      <rect x="20" y="52" width="80" height="56" rx="10" fill="currentColor" />
      <rect x="55" y="52" width="10" height="56" fill="white" opacity="0.55" />
      <g
        style={{
          transform: `translateY(${-lift - (open ? 18 : 0)}px) rotate(${open ? -12 : 0}deg)`,
          transformOrigin: "60px 46px",
          transition: "transform 260ms cubic-bezier(0.34, 1.56, 0.64, 1)",
        }}
      >
        <rect x="14" y="38" width="92" height="20" rx="7" fill="currentColor" opacity="0.9" />
        <rect x="55" y="38" width="10" height="20" fill="white" opacity="0.55" />
        <path d="M60 38c-9-15-25-15-25-3 0 9 15 11 25 11s25-2 25-11c0-12-16-12-25 3z" fill="currentColor" opacity="0.75" />
      </g>
    </svg>
  );
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
 * **La carte de l'offre.** Un pourcentage, un prix, un bouton.
 *
 * Ce qu'elle ne fait pas est ce qui la fait marcher. Pas de liste d'avantages,
 * pas d'illustration, pas de sur-titre : l'offre a déjà été annoncée, et ce
 * qu'on doit lire pour décider tient en quatre lignes. Une carte d'offre qui
 * argumente encore est une carte qui n'a pas confiance en son prix.
 *
 * Le fond va du bleu ciel au blanc, du haut vers le bas : le pourcentage est
 * dans la couleur, le prix et le bouton sont sur le blanc, là où on les lit
 * sans effort.
 */
export function DiscountCard({ onClose }: { onClose: () => void }) {
  const { t } = useI18n();
  const currency = usePresentment();
  const plan = pricing.DISCOUNT_YEARLY;
  const full = pricing.DISCOUNT_REFERENCE;
  const saved = pricing.discountSavingsPercent();
  const [pending, setPending] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);

  useEffect(() => {
    trackPaywallView("discount");
  }, []);

  async function subscribe() {
    setPending(true);
    setFailure(null);
    trackCheckoutStart("yearly_discount", "discount");
    const result = await startCheckout("yearly_discount");
    setPending(false);

    if (result.status === "redirect" && result.url) {
      window.location.href = result.url;
      return;
    }
    if (result.status === "already") {
      setFailure(t("app.paywall.already"));
      return;
    }
    setFailure(result.message ?? t("app.paywall.checkoutClosed"));
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center p-3 sm:items-center sm:p-6">
      <button
        type="button"
        aria-label={t("app.paywall.closeOffer")}
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
          aria-label={t("app.a11y.close")}
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
          <h2
            id="cadeau-title"
            className="mt-5 text-[28px] font-bold leading-[1.08] tracking-tight-title text-ink sm:text-[36px]"
          >
            {t("app.paywall.discountTitle", { pct: saved })}
            <br />
            {t("app.paywall.discountSubtitle")}
          </h2>

          <div className="mt-6 flex w-full items-center gap-4 rounded-[22px] bg-surface px-4 py-4 text-left shadow-[0_14px_34px_-18px_rgba(11,143,220,0.55)] sm:px-5">
            <SaleSeal percent={saved} />

            <div className="min-w-0">
              <p className="text-[14.5px] font-semibold text-offer-sky">
                {t("app.paywall.yearly")}
              </p>

              <p className="mt-0.5 flex flex-wrap items-baseline gap-x-2">
                <span className="numeral text-[26px] font-bold leading-none text-ink">
                  {pricing.priceText(pricing.presentmentAmount(plan, currency), currency)}
                </span>
                <span className="text-[15px] font-medium text-ink-secondary">
                  {t("app.paywall.perYear")}
                </span>
              </p>

              <s className="mt-1 block text-[15.5px] font-medium text-ink-tertiary">
                {pricing.priceText(pricing.presentmentAmount(full, currency), currency)}
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
            {t("app.paywall.discountCta", { pct: saved })}
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
              {t("app.paywall.discountYearly", {
                price: pricing.priceText(pricing.presentmentAmount(plan, currency), currency),
              })}
            </p>
          )}
        </div>
      </div>
    </div>
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
  const { t } = useI18n();
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
        <span className="text-[9.5px] font-semibold">{t("app.paywall.saleSeal")}</span>
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
 * rouvre l'offre. En bas à droite, hors du flux — et au-dessus du bouton
 * « Réviser ce cours » quand il flotte, pour que les deux pastilles ne se
 * mordent pas.
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
  const { t } = useI18n();
  const left = useCountdown(startedAt, discount.windowSeconds);
  if (left <= 0) return null;

  return (
    <Float>
      <button
        type="button"
        onClick={onOpen}
        aria-label={t("app.paywall.reopenOffer", { time: discount.countdownLabel(left) })}
        className="app-offer-badge pressable fixed right-4 z-40 flex items-center gap-2.5 rounded-pill bg-offer-sky px-4 py-3 text-white shadow-[0_16px_40px_-12px_rgba(11,143,220,0.6)] lg:right-8"
      >
        <span aria-hidden className="text-white">
          <GiftGlyph />
        </span>
        <span className="text-left">
          <span className="block text-[11px] font-semibold uppercase tracking-[0.08em] text-white/80">
            {t("app.paywall.yourOffer")}
          </span>
          <span className="block font-number text-[15px] font-bold tabular-nums" aria-hidden>
            {discount.countdown(left)}
          </span>
        </span>
      </button>
    </Float>
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
