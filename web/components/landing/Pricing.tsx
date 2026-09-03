"use client";

import { entitlement, pricing } from "@micabo/core";

import { Badge } from "@/components/ui/badge";
import { Card, CardPanel } from "@/components/ui/card";
import { useI18n } from "@/lib/i18n/client";
import { planCaption, planTitle, presentmentFor } from "@/lib/pricing-copy";

import { StartButton } from "./StartButton";
import { WaitlistForm } from "./WaitlistForm";

/**
 * Le prix, écrit.
 *
 * Une grille de prix qui cache son prix se lit comme un tunnel de vente. Et le pourcentage
 * d'économie est **calculé** depuis les deux offres, jamais écrit : une remise annoncée à côté de
 * deux prix qui la contredisent est une allégation commerciale fausse, et sur un site public elle
 * est indexée.
 *
 * Il n'y a pas encore de bouton d'achat, et il n'y en aura pas avant que l'encaissement existe.
 * Un bouton « S'abonner » qui mène à une page vide coûte plus cher en confiance que l'absence de
 * bouton.
 */
export function Pricing({ signedIn = false }: { signedIn?: boolean }) {
  const { t, locale } = useI18n();
  const currency = presentmentFor(locale);
  const saving = pricing.savingsPercent();

  return (
    <div className="mt-9">
      <div className="grid gap-4 sm:grid-cols-2">
        {pricing.PLANS.map((plan) => {
          const recommended = plan.kind === pricing.RECOMMENDED_PLAN.kind;
          return (
            <Card
              key={plan.kind}
              className={`lift ${recommended ? "border-ink bg-ink text-on-ink" : ""}`}
            >
              <CardPanel className="p-6">
              <div className="flex items-baseline justify-between gap-3">
                <p
                  className={`text-[15px] font-semibold ${
                    recommended ? "text-on-ink" : "text-ink"
                  }`}
                >
                  {planTitle(t, plan)}
                </p>
                {recommended ? (
                  <Badge className="rounded-pill bg-accent-vivid text-[11px] font-bold text-ink hover:bg-accent-vivid">
                    {t("landing.savePercent", { pct: saving })}
                  </Badge>
                ) : null}
              </div>

              <p
                className={`numeral mt-5 text-4xl font-bold ${
                  recommended ? "text-on-ink" : "text-ink"
                }`}
              >
                {pricing.priceText(pricing.presentmentAmount(plan, currency), currency)}
              </p>
              <p
                className={`mt-1 text-[13px] ${
                  recommended ? "text-on-ink-muted" : "text-ink-tertiary"
                }`}
              >
                {planCaption(t, plan, currency)}
              </p>

              <p
                className={`mt-5 border-t pt-5 text-[13px] leading-relaxed ${
                  recommended
                    ? "border-white/12 text-on-ink-muted"
                    : "border-hairline text-ink-secondary"
                }`}
              >
                {t("landing.pricingFeatures")}
                {recommended
                  ? ` ${t("landing.pricingTrial", { days: pricing.FREE_TRIAL_DAYS })}`
                  : ` ${t("landing.pricingNoTrial")}`}
              </p>
              </CardPanel>
            </Card>
          );
        })}
      </div>

      <Card className="mt-4">
      <CardPanel className="p-6">
        <p className="eyebrow text-ink-tertiary">{t("landing.pricingFreeEyebrow")}</p>
        <p className="mt-3 text-[15px] leading-relaxed text-ink-secondary">
          <strong className="font-semibold text-ink">{t("landing.pricingFreeLead")}</strong>
          {t("landing.pricingFreeBody", {
            sheet: Math.round(entitlement.FREE_TIER.readableSheetRatio * 100),
            cards: entitlement.FREE_TIER.cardsPerSession,
          })}
        </p>
      </CardPanel>
      </Card>

      <div className="mx-auto mt-10 flex flex-col items-center">
        <StartButton signedIn={signedIn} />
        <p className="mt-10 mb-3 text-center text-[13.5px] text-ink-tertiary">
          {t("landing.pricingNotOpen")}
        </p>
        <div className="w-full max-w-[440px]">
          <WaitlistForm source="pricing" size="compact" />
        </div>
      </div>
    </div>
  );
}
