"use client";

import { useState, type ReactNode } from "react";
import Link from "next/link";
import { ThinkingOrb } from "thinking-orbs";

import { pricing } from "@micabo/core";

import { BrandMark } from "@/components/BrandMark";
import { startCheckout } from "@/lib/actions/checkout";
import { PRIVACY_PATH, TERMS_PATH } from "@/lib/legal";

/**
 * L'offre, en un écran : ce que Pro ouvre, puis les deux formules.
 *
 * Quatre lignes, et seulement ce qui existe : cartes IA, fiches, répétition
 * espacée, mode examen. Pas de mock exam, pas de dictée vocale.
 */

export const PAYWALL_FEATURES = [
  {
    title: "Cartes IA illimitées",
    detail: "Importe PDF, photos, Word et YouTube",
    icon: "cards" as const,
  },
  {
    title: "Fiches de cours automatiques",
    detail: "Ton document devient une fiche à relire",
    icon: "sheet" as const,
  },
  {
    title: "Répétition espacée",
    detail: "Les cartes reviennent juste avant que tu oublies",
    icon: "repeat" as const,
  },
  {
    title: "Mode examen",
    detail: "Tu donnes la date, Micabo resserre le plan",
    icon: "exam" as const,
  },
] as const;

export function PaywallOffer({
  headingId,
  onSubscribed,
  extraAction,
}: {
  headingId: string;
  onSubscribed?: () => void;
  extraAction?: ReactNode;
}) {
  const [chosen, setChosen] = useState<pricing.PlanKind>("yearly");
  const [checkout, setCheckout] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  const selected = pricing.planFor(chosen);

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
      setCheckout("Tu es déjà abonné.");
      onSubscribed?.();
      return;
    }
    setCheckout(result.message ?? "L'abonnement n'est pas encore ouvert.");
  }

  return (
    <div className="flex min-h-0 flex-1 flex-col">
      <div className="min-h-0 flex-1 overflow-y-auto px-6 pb-2">
        <div className="flex items-center gap-2.5">
          <BrandMark size={36} />
          <h2
            id={headingId}
            className="flex items-center gap-2 text-[22px] font-bold tracking-tight text-ink"
          >
            Micabo
            <span className="rounded-pill bg-accent px-2 py-0.5 text-[11px] font-bold tracking-wide text-on-ink">
              Pro
            </span>
          </h2>
        </div>

        <ul className="mt-6 space-y-3.5">
          {PAYWALL_FEATURES.map((feature) => (
            <li key={feature.title} className="flex items-start gap-3">
              <span
                aria-hidden
                className="mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-accent-soft text-accent"
              >
                <FeatureIcon name={feature.icon} />
              </span>
              <span className="min-w-0">
                <span className="block text-[15px] font-semibold leading-tight text-ink">
                  {feature.title}
                </span>
                <span className="mt-0.5 block text-[13px] leading-snug text-ink-tertiary">
                  {feature.detail}
                </span>
              </span>
            </li>
          ))}
        </ul>

        <div className="mt-6 space-y-2.5">
          {pricing.offers().map((plan) => (
            <PlanChoice
              key={plan.productId}
              plan={plan}
              selected={chosen === plan.kind}
              onSelect={() => setChosen(plan.kind)}
            />
          ))}
        </div>
      </div>

      <div className="px-6 pb-6 pt-4">
        <button
          type="button"
          onClick={() => void subscribe()}
          disabled={pending}
          className="pressable shiny flex h-14 w-full items-center justify-center gap-2 rounded-button bg-accent text-[16px] font-semibold text-on-ink disabled:opacity-70"
        >
          {pending ? <ThinkingOrb state="connecting" size={20} theme="dark" /> : null}
          {pricing.hasTrial(selected)
            ? `Commencer mon essai de ${selected.trialDays} jours`
            : "S'abonner"}
        </button>

        {extraAction}

        {checkout ? (
          <p
            className="mt-3 rounded-button bg-canvas px-4 py-3 text-[13.5px] text-ink-secondary"
            role="status"
          >
            {checkout}
          </p>
        ) : (
          <p className="mt-3 text-center text-[12px] leading-relaxed text-ink-tertiary">
            En t&apos;abonnant, tu acceptes nos{" "}
            <Link href={TERMS_PATH} className="underline underline-offset-2">
              Conditions d&apos;utilisation
            </Link>{" "}
            et notre{" "}
            <Link href={PRIVACY_PATH} className="underline underline-offset-2">
              Politique de confidentialité
            </Link>
            .
          </p>
        )}
      </div>
    </div>
  );
}

export function PlanChoice({
  plan,
  selected,
  onSelect,
}: {
  plan: pricing.Plan;
  selected: boolean;
  onSelect: () => void;
}) {
  const badge = pricing.trialBadge(plan);

  return (
    <button
      type="button"
      onClick={onSelect}
      aria-pressed={selected}
      className={`pressable relative flex w-full items-center justify-between gap-4 rounded-group px-5 py-4 text-left transition-[border-color,color,background-color] duration-hover ${
        selected
          ? "border-2 border-accent bg-accent-soft/50 text-accent"
          : "border border-stroke-strong bg-surface text-ink"
      }`}
    >
      {badge ? (
        <span
          className={`absolute -top-2.5 right-3 rounded-pill px-2 py-0.5 text-[10.5px] font-bold text-on-ink ${
            selected ? "bg-accent" : "bg-accent-vivid"
          }`}
        >
          {badge}
        </span>
      ) : null}
      <div className="min-w-0">
        <p className={`text-[15px] font-bold ${selected ? "text-accent" : "text-ink"}`}>
          {plan.title}
        </p>
        <p className="mt-0.5 text-[12.5px] leading-snug text-ink-tertiary">
          {pricing.planRenewalCopy(plan)}
        </p>
      </div>
      <div className="shrink-0 text-right">
        <p
          className={`numeral text-[18px] font-bold leading-none ${
            selected ? "text-accent" : "text-ink"
          }`}
        >
          {pricing.planDisplayedPrice(plan)}
        </p>
        <p className="mt-1 text-[11.5px] text-ink-tertiary">{pricing.planDisplayedUnit(plan)}</p>
      </div>
    </button>
  );
}

function FeatureIcon({ name }: { name: (typeof PAYWALL_FEATURES)[number]["icon"] }) {
  const className = "h-4 w-4";
  if (name === "cards") {
    return (
      <svg aria-hidden viewBox="0 0 20 20" className={className}>
        <rect
          x="3.2"
          y="5"
          width="10.2"
          height="12"
          rx="2"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.6"
        />
        <path
          d="M6.6 3.4h8.6A1.8 1.8 0 0 1 17 5.2v9.4"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.6"
          strokeLinecap="round"
        />
      </svg>
    );
  }
  if (name === "sheet") {
    return (
      <svg aria-hidden viewBox="0 0 20 20" className={className}>
        <path
          d="M5.5 3.4h6.2L15 6.8v9.8H5.5z"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.6"
          strokeLinejoin="round"
        />
        <path
          d="M11.6 3.4v3.4H15M8 10.4h4.4M8 13h3.2"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.5"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    );
  }
  if (name === "repeat") {
    return (
      <svg aria-hidden viewBox="0 0 20 20" className={className}>
        <path
          d="M4.2 9.2A5.8 5.8 0 0 1 14.8 7.4L16 5.8M15.8 10.8A5.8 5.8 0 0 1 5.2 12.6L4 14.2"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.6"
          strokeLinecap="round"
        />
        <path
          d="M13.4 5.6 16 5.8l.1 2.6M6.6 14.4 4 14.2l-.1-2.6"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.6"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    );
  }
  return (
    <svg aria-hidden viewBox="0 0 20 20" className={className}>
      <circle cx="10" cy="10" r="6.4" fill="none" stroke="currentColor" strokeWidth="1.6" />
      <circle cx="10" cy="10" r="2.2" fill="none" stroke="currentColor" strokeWidth="1.6" />
      <path
        d="M10 3.6v2.2M10 14.2v2.2M3.6 10h2.2M14.2 10h2.2"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinecap="round"
      />
    </svg>
  );
}
