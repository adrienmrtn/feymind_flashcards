"use client";

import { useEffect, useId, useState } from "react";
import type { Route } from "next";
import { usePathname, useRouter, useSearchParams } from "next/navigation";

import { pricing } from "@micabo/core";

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
 * Le court accueil (preuve, essai, rappel) précède l'offre — sauf quand
 * une porte (deuxième cours, session) ouvre Pro tout de suite.
 *
 * `isPaid` - pas `isPro`. Sans ça, tout le monde sans ligne d'abonnement est
 * traité comme Pro, et cette carte ne s'ouvre jamais.
 */

type Stage = "social" | "trial" | "reminder" | "plans";

const STAGES: Stage[] = ["social", "trial", "reminder", "plans"];

export function PaywallHost({ isPaid }: { isPaid: boolean }) {
  const params = useSearchParams();
  const pathname = usePathname();
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [startAt, setStartAt] = useState<Stage>("social");
  const debugReplay = params.get("debug") === "paywall";

  useEffect(() => {
    function onRequest() {
      if (isPaid && !debugReplay) return;
      setStartAt("plans");
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

      setStartAt(force && !debugReplay ? "plans" : "social");
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
  return (
    <PaywallCard
      key={`${debugReplay ? "debug" : "live"}-${startAt}`}
      startAt={startAt}
      onClose={close}
    />
  );
}

export function PaywallCard({
  onClose,
  startAt = "social",
}: {
  onClose: () => void;
  startAt?: Stage;
}) {
  const titleId = useId();
  const [stage, setStage] = useState<Stage>(startAt);
  const index = STAGES.indexOf(stage);

  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      if (event.key !== "Escape") return;
      event.preventDefault();
      onClose();
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  function next() {
    const following = STAGES[index + 1];
    if (following) setStage(following);
    else onClose();
  }

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
        className="paywall-card relative flex max-h-[min(780px,92svh)] w-full max-w-[440px] flex-col overflow-hidden rounded-[28px] bg-surface shadow-[0_28px_90px_-20px_rgba(25,23,20,0.5)]"
      >
        <div className="flex items-center justify-between px-5 pt-4">
          {startAt === "social" ? (
            <div className="flex items-center gap-1.5" aria-hidden>
              {STAGES.map((item, position) => (
                <span
                  key={item}
                  className={`h-1.5 rounded-pill transition-all duration-menu ${
                    position === index
                      ? "w-6 bg-ink"
                      : position < index
                        ? "w-1.5 bg-accent-vivid"
                        : "w-1.5 bg-stroke-strong"
                  }`}
                />
              ))}
            </div>
          ) : (
            <span />
          )}
          <button
            type="button"
            aria-label="Fermer"
            onClick={onClose}
            className="pressable -mr-1 flex h-9 w-9 items-center justify-center rounded-full text-ink-tertiary hover:bg-canvas"
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

        {stage === "plans" ? (
          <PaywallOffer headingId={titleId} />
        ) : (
          <>
            <div className="min-h-0 flex-1 overflow-y-auto px-6 pb-2 pt-3">
              <div key={stage} className="rise">
                {stage === "social" ? <SocialStep headingId={titleId} /> : null}
                {stage === "trial" ? <TrialStep headingId={titleId} /> : null}
                {stage === "reminder" ? <ReminderStep headingId={titleId} /> : null}
              </div>
            </div>
            <div className="px-6 pb-6 pt-3">
              <button
                type="button"
                onClick={next}
                className="pressable shiny flex h-14 w-full items-center justify-center rounded-button bg-accent text-[16px] font-semibold text-on-ink"
              >
                {stage === "social"
                  ? "Continuer"
                  : stage === "trial"
                    ? `Continuer pour ${pricing.priceText(0)}`
                    : "Continuer gratuitement"}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

function SocialStep({ headingId }: { headingId: string }) {
  return (
    <div>
      <h2 id={headingId} className="flex flex-col items-center text-center">
        <Stars rating={4.8} />
        <span className="numeral mt-3 text-[40px] font-bold leading-none tracking-display text-ink">
          4,8
          <span className="text-[20px] font-semibold text-ink-tertiary"> / 5</span>
        </span>
      </h2>

      <div className="mt-6">
        <p className="text-[14px] leading-relaxed text-ink-secondary">
          Micabo se base sur la science et la répétition espacée pour optimiser la
          rétention.
        </p>
        <div className="mt-3 space-y-2">
          {STUDIES.map((study, index) => (
            <a
              key={study.doi}
              href={study.href}
              target="_blank"
              rel="noreferrer"
              className="paywall-stagger flex items-start gap-3 rounded-button bg-canvas px-4 py-3 transition-colors duration-hover hover:bg-accent-soft"
              style={{ animationDelay: `${80 + index * 80}ms` }}
            >
              <span
                aria-hidden
                className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-tile bg-accent-soft text-accent"
              >
                <ResearchIcon />
              </span>
              <span className="min-w-0">
                <span className="block text-[13.5px] font-medium text-ink">{study.title}</span>
                <span className="mt-0.5 block text-[12px] text-ink-tertiary">{study.source}</span>
              </span>
            </a>
          ))}
        </div>
      </div>
    </div>
  );
}

function TrialStep({ headingId }: { headingId: string }) {
  return (
    <div className="flex min-h-[340px] flex-col items-center justify-center py-6 text-center">
      <p className="eyebrow text-accent">L&apos;essai</p>
      <span aria-hidden className="mt-6 text-accent">
        <Gift />
      </span>
      <h2
        id={headingId}
        className="mt-6 text-[26px] font-bold leading-[1.15] tracking-tight-title text-ink"
      >
        On veut te laisser tout essayer, sans rien payer.
      </h2>
    </div>
  );
}

function ReminderStep({ headingId }: { headingId: string }) {
  return (
    <div className="flex min-h-[360px] flex-col items-center justify-center py-6 text-center">
      <span aria-hidden className="bell-sway mb-7 text-caution-vivid">
        <Bell />
      </span>
      <h2
        id={headingId}
        className="text-[24px] font-bold leading-[1.15] tracking-tight-title text-ink"
      >
        On t&apos;envoie un e-mail avant la fin de l&apos;essai.
      </h2>
      <p className="mt-5 text-[17px] font-semibold text-ink">Aucun paiement n&apos;est dû aujourd&apos;hui.</p>
    </div>
  );
}

function Stars({ rating }: { rating: number }) {
  return (
    <span className="flex items-center gap-1" aria-hidden>
      {Array.from({ length: 5 }, (_, index) => {
        const fill = Math.min(1, Math.max(0, rating - index));
        return <Star key={index} fill={fill} clipId={`paywall-star-${index}`} />;
      })}
    </span>
  );
}

function Star({ fill, clipId }: { fill: number; clipId: string }) {
  return (
    <svg viewBox="0 0 20 20" className="h-7 w-7 text-caution-vivid">
      <defs>
        <clipPath id={clipId}>
          <rect x="0" y="0" width={20 * fill} height="20" />
        </clipPath>
      </defs>
      <path
        d="M10 2.4l2.2 4.6 5 .7-3.6 3.5.9 5.1L10 13.9 5.5 16.3l.9-5.1L2.8 7.7l5-.7z"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.4"
        strokeLinejoin="round"
      />
      <path
        d="M10 2.4l2.2 4.6 5 .7-3.6 3.5.9 5.1L10 13.9 5.5 16.3l.9-5.1L2.8 7.7l5-.7z"
        fill="currentColor"
        clipPath={`url(#${clipId})`}
      />
    </svg>
  );
}

function ResearchIcon() {
  return (
    <svg aria-hidden viewBox="0 0 20 20" className="h-4 w-4">
      <path
        d="M5.5 3.5h6.2L15 6.8v9.7H5.5z"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinejoin="round"
      />
      <path
        d="M11.6 3.5v3.4H15"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinejoin="round"
      />
      <path
        d="M8 10.2h4.4M8 12.8h3.2"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinecap="round"
      />
    </svg>
  );
}

function Gift() {
  return (
    <svg aria-hidden viewBox="0 0 96 96" className="h-[96px] w-[96px]">
      <rect x="16" y="38" width="64" height="44" rx="8" fill="currentColor" />
      <rect x="16" y="28" width="64" height="16" rx="6" fill="currentColor" opacity="0.85" />
      <rect x="44" y="28" width="8" height="54" fill="#dff4ec" />
      <path
        d="M48 28c-8-12-20-12-20-2 0 8 12 10 20 10 8 0 20-2 20-10 0-10-12-10-20 2z"
        fill="#16c08c"
      />
    </svg>
  );
}

function Bell() {
  return (
    <svg aria-hidden viewBox="0 0 88 88" className="h-[88px] w-[88px]">
      <path
        d="M44 12c-11 0-20 9-20 22v10c0 6-3 11-8 14h56c-5-3-8-8-8-14V34c0-13-9-22-20-22z"
        fill="currentColor"
      />
      <path
        d="M34 70c2.6 6 7.2 10 10 10s7.4-4 10-10"
        fill="none"
        stroke="currentColor"
        strokeWidth="6"
        strokeLinecap="round"
      />
      <circle cx="62" cy="22" r="8" fill="#c93b2b" />
    </svg>
  );
}

/**
 * Trois papiers, et rien d'inventé. Ce sont les références que retiennent les apps
 * de révision - l'effet d'espacement, le rappel actif, la courbe d'Ebbinghaus
 * répliquée. Les liens mènent aux versions ouvertes.
 */
const STUDIES = [
  {
    title: "L'effet d'espacement, mesuré",
    source: "Cepeda et al., Psychological Bulletin, 2006",
    doi: "10.1037/0033-2909.132.3.354",
    href: "https://doi.org/10.1037/0033-2909.132.3.354",
  },
  {
    title: "Le rappel actif bat la relecture",
    source: "Karpicke & Roediger, Science, 2008",
    doi: "10.1126/science.1152408",
    href: "https://doi.org/10.1126/science.1152408",
  },
  {
    title: "La courbe d'Ebbinghaus, répliquée",
    source: "Murre & Dros, PLOS ONE, 2015",
    doi: "10.1371/journal.pone.0120644",
    href: "https://doi.org/10.1371/journal.pone.0120644",
  },
] as const;
