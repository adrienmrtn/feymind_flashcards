"use client";

import Link from "next/link";

import { pricing } from "@micabo/core";

import { useI18n } from "@/lib/i18n/client";
import { planRenewalCopy, planTitle, presentmentFor, trialBadge } from "@/lib/pricing-copy";

import { Reveal } from "./Reveal";

/**
 * **Le prix, écrit.** Les deux offres du paywall de l'app, l'annuel mis en avant.
 *
 * Aucun montant n'est recopié ici : tout vient de `@micabo/core/pricing` (le catalogue que
 * l'app et Stripe partagent), et les mots de `pricing-copy`. Quand le catalogue change, la
 * vitrine change avec lui, **aux prix du pays du visiteur** — ceux que l'App Store lui
 * vendrait (39,99 € en Espagne, $59.99 aux États-Unis) —, écrits dans la langue du site.
 *
 * Une grille de prix qui cache son prix se lit comme un tunnel de vente : le prix est donc
 * le plus gros texte de la carte, et l'essai est dit à côté, pas en petit dessous.
 */
export function Pricing({
  signedIn = false,
  country = null,
}: {
  signedIn?: boolean;
  /** Le pays des prix, résolu côté serveur (`readPricingCountry`). */
  country?: string | null;
}) {
  const { t, locale } = useI18n();
  const presentment = presentmentFor(locale, country);
  const [yearly, weekly] = pricing.offers();
  const features = [
    t("landing.pricingFeature1"),
    t("landing.pricingFeature2"),
    t("landing.pricingFeature3"),
    t("landing.pricingFeature4"),
  ];
  const href = signedIn ? "/app" : "/commencer";

  const card = (plan: pricing.Plan, recommended: boolean) => {
    const amount = pricing.planPriceText(plan, presentment);
    const monthly = pricing.monthlyEquivalent(plan, presentment);
    const unit = t(plan.period === "year" ? "app.paywall.periodYear" : "app.paywall.periodWeek");
    const badge = trialBadge(t, plan, presentment);
    return (
      <div
        className={`lp-card flex h-full flex-col rounded-[30px] p-6 sm:p-8 ${
          recommended ? "lp-gradient-ring" : "bg-surface lp-surface-shadow"
        }`}
      >
        <div className="flex min-h-7 flex-wrap items-center gap-2">
          <p className="text-[17px] font-extrabold text-ink">{planTitle(t, plan)}</p>
          {recommended ? (
            <span className="lp-gradient-fill rounded-pill px-2.5 py-1 text-[11.5px] font-extrabold text-white">
              {t("landing.pricingRecommended")}
            </span>
          ) : null}
          {badge ? (
            <span className="rounded-pill bg-correct-soft px-2.5 py-1 text-[11.5px] font-extrabold text-correct-ink">{badge}</span>
          ) : null}
        </div>
        <p className="mt-5 flex items-baseline gap-1.5">
          <span className="numeral text-[44px] font-extrabold leading-none tracking-display text-ink">{amount}</span>
          <span className="text-[15px] font-bold text-ink-tertiary">/ {unit}</span>
        </p>
        <p className="mt-2 min-h-[22px] text-[14.5px] font-semibold text-ink-secondary">
          {monthly ? t("landing.pricingMonthly", { price: monthly }) : planRenewalCopy(t, plan, presentment)}
        </p>
        {monthly ? (
          <p className="mt-1 text-[13px] text-ink-tertiary">{planRenewalCopy(t, plan, presentment)}</p>
        ) : (
          <p className="mt-1 text-[13px] text-ink-tertiary">&nbsp;</p>
        )}
        <Link
          href={href}
          className={`mt-7 inline-flex h-12 items-center justify-center rounded-[16px] text-[15.5px] font-extrabold ${
            recommended ? "lp-cta bg-accent text-on-ink" : "lp-card bg-surface-muted text-ink"
          }`}
        >
          {recommended && badge ? t("landing.pricingTrialCta", { days: pricing.trialDays(plan, presentment) }) : t("landing.heroCta")}
        </Link>
      </div>
    );
  };

  return (
    <div className="mt-12 sm:mt-14">
      <div className="mx-auto grid max-w-[880px] gap-5 md:grid-cols-2">
        <Reveal className="h-full">{card(yearly, true)}</Reveal>
        <Reveal delay={1} className="h-full">{card(weekly, false)}</Reveal>
      </div>

      <Reveal delay={2}>
        <ul className="mx-auto mt-8 grid max-w-[880px] gap-x-6 gap-y-3 sm:grid-cols-2">
          {features.map((feature) => (
            <li key={feature} className="flex items-start gap-3 text-[15px] font-semibold text-ink">
              <span className="mt-0.5 flex size-[22px] shrink-0 items-center justify-center rounded-full bg-accent-soft text-accent">
                <svg aria-hidden viewBox="0 0 16 16" className="size-3" fill="none" stroke="currentColor" strokeWidth="2.8" strokeLinecap="round" strokeLinejoin="round">
                  <path d="m3.5 8.4 2.9 2.9 6.1-6.6" />
                </svg>
              </span>
              {feature}
            </li>
          ))}
        </ul>
        <p className="mx-auto mt-7 max-w-[60ch] text-center text-[13.5px] text-ink-tertiary">{t("landing.pricingSameAccount")}</p>
      </Reveal>
    </div>
  );
}
