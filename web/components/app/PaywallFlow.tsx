"use client";

import { useEffect, useState } from "react";
import type { Route } from "next";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { ThinkingOrb } from "thinking-orbs";

import { pricing } from "@micabo/core";

import { startCheckout } from "@/lib/actions/checkout";
import { isDebugToolsEnabled } from "@/lib/debug";
import {
  isPaywallDismissed,
  isPaywallPending,
  markPaywallDismissed,
  persistStoredAnswers,
  shouldOpenPaywall,
} from "@/lib/onboarding/persist";

/**
 * Le paywall, **posé sur le tableau de bord**.
 *
 * Quatre étapes, jamais plein écran : l'étagère reste visible autour. L'étudiant
 * débarque d'abord, puis l'offre se pose - pas l'inverse. La croix est là dès la
 * première image.
 *
 * Les prix viennent du même catalogue que la landing. La case « je suis étudiant »
 * permute l'annuel : 83,88 € avec essai, ou 59,99 € barré de l'ancien, sans essai.
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
  const debugReplay = isDebugToolsEnabled() && params.get("debug") === "paywall";

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

      // Le dashboard se pose d'abord. L'offre arrive ensuite, pas à la place.
      timer = window.setTimeout(() => {
        if (!cancelled) setOpen(true);
      }, 980);
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
  const [stage, setStage] = useState<Stage>("social");
  const index = STAGES.indexOf(stage);

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
        aria-labelledby="paywall-title"
        className="paywall-card relative flex max-h-[min(760px,92svh)] w-full max-w-[440px] flex-col overflow-hidden rounded-[28px] bg-surface shadow-[0_28px_90px_-20px_rgba(25,23,20,0.5)]"
      >
        <div className="flex items-center justify-between px-5 pt-4">
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

        <div className="min-h-0 flex-1 overflow-y-auto px-6 pb-2 pt-3">
          <div key={stage} className="rise">
            {stage === "social" ? <SocialStep /> : null}
            {stage === "trial" ? <TrialStep /> : null}
            {stage === "reminder" ? <ReminderStep /> : null}
            {stage === "plans" ? <PlansStep /> : null}
          </div>
        </div>

        {stage !== "plans" ? (
          <div className="px-6 pb-6 pt-3">
            <button
              type="button"
              onClick={next}
              className="pressable shiny flex h-14 w-full items-center justify-center rounded-button bg-ink text-[16px] font-semibold text-on-ink"
            >
              {stage === "social"
                ? "Continuer"
                : stage === "trial"
                  ? `Continuer pour ${pricing.priceText(0)}`
                  : "Continuer gratuitement"}
            </button>
          </div>
        ) : null}
      </div>
    </div>
  );
}

function SocialStep() {
  return (
    <div>
      <p className="eyebrow text-accent">Preuve sociale</p>
      <h2
        id="paywall-title"
        className="mt-2 text-[30px] font-bold leading-[1.08] tracking-tight-title text-ink"
      >
        <span className="count-in numeral inline-block">
          <CountUp to={100000} />+
        </span>
        <span className="mt-1 block text-[22px] font-semibold tracking-tight-title">
          utilisateurs
        </span>
      </h2>
      <p className="mt-2 text-[15px] leading-relaxed text-ink-secondary">
        Ils révisent avec Micabo. Les mêmes écoles, la même méthode - la
        répétition espacée, mesurée depuis plus d&apos;un siècle.
      </p>

      <div className="mt-6 grid grid-cols-2 gap-2">
        {SCHOOLS.map((school, index) => (
          <div
            key={school.name}
            className="paywall-stagger flex h-[58px] items-center justify-center rounded-tile bg-canvas"
            style={{ animationDelay: `${80 + index * 70}ms` }}
          >
            <span className="text-[13px] font-bold tracking-[0.06em] text-ink uppercase">
              {school.mark}
            </span>
          </div>
        ))}
      </div>

      <div className="mt-6">
        <p className="eyebrow text-ink-tertiary">Preuve scientifique</p>
        <p className="mt-1.5 text-[13px] leading-relaxed text-ink-secondary">
          La rétention tient à l&apos;espacement, pas au volume. Voici les
          études.
        </p>
        <div className="mt-3 space-y-2">
          {STUDIES.map((study, index) => (
            <a
              key={study.doi}
              href={study.href}
              target="_blank"
              rel="noreferrer"
              className="paywall-stagger block rounded-button bg-canvas px-4 py-3 transition-colors duration-hover hover:bg-accent-soft"
              style={{ animationDelay: `${360 + index * 80}ms` }}
            >
              <p className="text-[13.5px] font-medium text-ink">{study.title}</p>
              <p className="mt-0.5 text-[12px] text-ink-tertiary">{study.source}</p>
            </a>
          ))}
        </div>
      </div>
    </div>
  );
}

function TrialStep() {
  return (
    <div className="flex min-h-[340px] flex-col justify-center py-4">
      <p className="eyebrow text-accent">L&apos;essai</p>
      <h2
        id="paywall-title"
        className="mt-2 text-[26px] font-bold leading-[1.15] tracking-tight-title text-ink"
      >
        On veut vous permettre de tester toutes les fonctionnalités
        gratuitement.
      </h2>
      <p className="mt-3 text-[15px] leading-relaxed text-ink-secondary">
        Cours illimités, fiches entières, cartes, mode examen. Rien n&apos;est
        fermé pendant l&apos;essai.
      </p>

      <ul className="mt-7 space-y-3">
        {[
          "Quiz et cartes sans plafond",
          "La fiche entière, pas les sept dixièmes",
          "Révisions espacées, au bon moment",
          "Le planning se réorganise autour de l'examen",
        ].map((line, index) => (
          <li
            key={line}
            className="paywall-stagger flex items-center gap-3"
            style={{ animationDelay: `${120 + index * 80}ms` }}
          >
            <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-accent-soft text-accent">
              <svg aria-hidden viewBox="0 0 20 20" className="h-3.5 w-3.5">
                <path
                  d="M4 10.5l4 4 8-9"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2.4"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            </span>
            <span className="text-[14.5px] text-ink">{line}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}

function ReminderStep() {
  return (
    <div className="flex min-h-[360px] flex-col items-center justify-center py-6 text-center">
      <span aria-hidden className="bell-sway mb-7 text-caution-vivid">
        <Bell />
      </span>
      <h2
        id="paywall-title"
        className="text-[24px] font-bold leading-[1.15] tracking-tight-title text-ink"
      >
        On vous envoie un e-mail avant la fin de l&apos;essai gratuit.
      </h2>
      <p className="mt-5 text-[17px] font-semibold text-ink">
        Aucun paiement n&apos;est dû aujourd&apos;hui.
      </p>
      <p className="mt-2 max-w-[34ch] text-[14px] leading-relaxed text-ink-secondary">
        Un rappel la veille. Résiliable en quinze secondes, avant le premier
        prélèvement.
      </p>
    </div>
  );
}

function PlansStep() {
  const [student, setStudent] = useState(false);
  const [chosen, setChosen] = useState<pricing.PlanKind>("yearly");
  const [checkout, setCheckout] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  const yearly = pricing.yearlyFor(student);
  const weekly = pricing.WEEKLY;
  const plans = [yearly, weekly];

  async function subscribe() {
    setPending(true);
    setCheckout(null);
    const result = await startCheckout(chosen, { student });
    setPending(false);
    if (result.status === "redirect" && result.url) {
      window.location.href = result.url;
      return;
    }
    if (result.status === "already") {
      setCheckout("Vous êtes déjà abonné.");
      return;
    }
    setCheckout(result.message ?? "L'abonnement n'est pas encore ouvert.");
  }

  return (
    <div>
      <p className="eyebrow text-accent">Micabo Pro</p>
      <h2
        id="paywall-title"
        className="mt-2 text-[26px] font-bold leading-[1.12] tracking-tight-title text-ink"
      >
        Choisissez comment vous révisez.
      </h2>

      <label className="mt-5 flex cursor-pointer items-center gap-3 rounded-button bg-canvas px-4 py-3.5">
        <input
          type="checkbox"
          checked={student}
          onChange={(event) => setStudent(event.target.checked)}
          className="h-4 w-4 accent-accent"
        />
        <span className="text-[14.5px] font-medium text-ink">Je suis étudiant</span>
      </label>

      <div className="mt-4 space-y-2.5">
        {plans.map((plan) => {
          const selected = chosen === plan.kind;
          const monthly = pricing.monthlyEquivalent(plan);
          const isYearly = plan.kind === "yearly";
          return (
            <button
              key={`${plan.productId}-${student}`}
              type="button"
              onClick={() => setChosen(plan.kind)}
              className={`pressable flex w-full items-center justify-between gap-4 rounded-group px-5 py-4 text-left transition-colors duration-hover ${
                selected ? "bg-ink text-on-ink" : "bg-canvas"
              }`}
            >
              <div>
                <p className="flex flex-wrap items-center gap-2 text-[15px] font-semibold">
                  {plan.title}
                  {isYearly && !student ? (
                    <span className="rounded-pill bg-accent-vivid px-2 py-0.5 text-[10.5px] font-bold text-ink">
                      {pricing.FREE_TRIAL_DAYS} jours offerts
                    </span>
                  ) : null}
                  {isYearly && student ? (
                    <span className="rounded-pill bg-accent-vivid px-2 py-0.5 text-[10.5px] font-bold text-ink">
                      Tarif étudiant
                    </span>
                  ) : null}
                </p>
                <p
                  className={`mt-0.5 text-[13px] ${
                    selected ? "text-on-ink-muted" : "text-ink-tertiary"
                  }`}
                >
                  {isYearly ? (
                    <>
                      {student ? (
                        <>
                          <span className="line-through">
                            {pricing.priceText(pricing.YEARLY.price)}
                          </span>
                          {" · "}
                          {pricing.priceText(plan.price)} / an · sans essai
                        </>
                      ) : (
                        <>
                          {pricing.priceText(plan.price)} / an · essai de{" "}
                          {pricing.FREE_TRIAL_DAYS} jours
                        </>
                      )}
                    </>
                  ) : (
                    <>sans essai gratuit</>
                  )}
                </p>
              </div>
              <div className="shrink-0 text-right">
                <p className="numeral text-[22px] font-bold leading-none">
                  {monthly ?? pricing.priceText(plan.price)}
                </p>
                <p
                  className={`mt-1 text-[11.5px] ${
                    selected ? "text-on-ink-muted" : "text-ink-tertiary"
                  }`}
                >
                  {monthly ? "/ mois" : "/ semaine"}
                </p>
              </div>
            </button>
          );
        })}
      </div>

      <button
        type="button"
        onClick={() => void subscribe()}
        disabled={pending}
        className="pressable shiny mt-5 flex h-14 w-full items-center justify-center gap-2 rounded-button bg-ink text-[16px] font-semibold text-on-ink disabled:opacity-70"
      >
        {pending ? <ThinkingOrb state="connecting" size={20} theme="dark" /> : null}
        {chosen === "yearly" && !student
          ? `Essayer ${pricing.FREE_TRIAL_DAYS} jours`
          : "S'abonner"}
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
          {chosen === "yearly" && !student
            ? `Aucun paiement aujourd'hui. Puis ${pricing.priceText(yearly.price)} / an.`
            : chosen === "yearly"
              ? `${pricing.priceText(yearly.price)} / an, dès maintenant.`
              : `${pricing.priceText(weekly.price)} / semaine, dès maintenant.`}
        </p>
      )}
    </div>
  );
}

function CountUp({ to }: { to: number }) {
  const [value, setValue] = useState(0);

  useEffect(() => {
    const start = performance.now();
    const duration = 980;
    let frame = 0;

    function tick(now: number) {
      const t = Math.min(1, (now - start) / duration);
      const eased = 1 - (1 - t) ** 3;
      setValue(Math.round(to * eased));
      if (t < 1) frame = requestAnimationFrame(tick);
    }

    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [to]);

  return <>{value.toLocaleString("fr-FR")}</>;
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

const SCHOOLS = [
  { name: "Harvard", mark: "Harvard" },
  { name: "HEC", mark: "HEC Paris" },
  { name: "EPFL", mark: "EPFL" },
  { name: "X", mark: "X · Polytechnique" },
] as const;

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
