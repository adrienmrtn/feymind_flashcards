import { entitlement, pricing } from "@micabo/core";

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
  const saving = pricing.savingsPercent();

  return (
    <div className="mt-9">
      <div className="grid gap-4 sm:grid-cols-2">
        {pricing.PLANS.map((plan) => {
          const recommended = plan.kind === pricing.RECOMMENDED_PLAN.kind;
          return (
            <div
              key={plan.kind}
              className={`lift rounded-group p-6 ${
                recommended ? "bg-ink text-on-ink" : "paper bg-surface"
              }`}
            >
              <div className="flex items-baseline justify-between gap-3">
                <p
                  className={`text-[15px] font-semibold ${
                    recommended ? "text-on-ink" : "text-ink"
                  }`}
                >
                  {plan.title}
                </p>
                {recommended ? (
                  <p className="rounded-pill bg-accent-vivid px-2.5 py-1 text-[11px] font-bold text-ink">
                    Économise {saving} %
                  </p>
                ) : null}
              </div>

              <p
                className={`numeral mt-5 text-4xl font-bold ${
                  recommended ? "text-on-ink" : "text-ink"
                }`}
              >
                {pricing.priceText(plan.price)}
              </p>
              <p
                className={`mt-1 text-[13px] ${
                  recommended ? "text-on-ink-muted" : "text-ink-tertiary"
                }`}
              >
                {pricing.planCaption(plan)}
              </p>

              <p
                className={`mt-5 border-t pt-5 text-[13px] leading-relaxed ${
                  recommended
                    ? "border-white/12 text-on-ink-muted"
                    : "border-hairline text-ink-secondary"
                }`}
              >
                Cours et cartes sans limite, mode examen, et la fiche entière.
                {recommended
                  ? ` ${pricing.FREE_TRIAL_DAYS} jours offerts.`
                  : " Sans essai."}
              </p>
            </div>
          );
        })}
      </div>

      <div className="paper mt-4 rounded-group bg-surface p-6">
        <p className="eyebrow text-ink-tertiary">Sans payer</p>
        <p className="mt-3 text-[15px] leading-relaxed text-ink-secondary">
          <strong className="font-semibold text-ink">Un cours entier à importer</strong>, dont tu
          lis les {Math.round(entitlement.FREE_TIER.readableSheetRatio * 100)} % de la fiche, et{" "}
          {entitlement.FREE_TIER.cardsPerSession} cartes par session. De quoi voir Micabo tourner
          sur ton propre cours avant de décider quoi que ce soit — ce qui est le seul essai qui
          veuille dire quelque chose.
        </p>
      </div>

      <div className="mx-auto mt-10 flex flex-col items-center">
        <StartButton signedIn={signedIn} />
        <p className="mt-10 mb-3 text-center text-[13.5px] text-ink-tertiary">
          L&apos;abonnement n&apos;est pas encore ouvert. On t&apos;écrit le jour J.
        </p>
        <div className="w-full max-w-[440px]">
          <WaitlistForm source="pricing" size="compact" />
        </div>
      </div>
    </div>
  );
}
