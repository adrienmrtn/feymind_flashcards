"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";

import { entitlement, pricing } from "@micabo/core";

import { useOnboarding } from "@/lib/onboarding/store";
import { startCheckout } from "@/lib/actions/checkout";
import { saveOnboarding, type SaveResult } from "@/lib/actions/onboarding";

/**
 * Le paywall, **et il est volontairement vide.**
 *
 * Il n'y a pas de bouton d'achat, parce qu'il n'y a pas d'encaissement : Stripe derrière RevenueCat
 * arrive à l'étape 5. Un bouton « S'abonner » qui mène à une page blanche coûte plus cher en
 * confiance que l'absence de bouton, et un paywall qui encaisse à moitié est la seule chose qu'on ne
 * peut pas livrer à moitié.
 *
 * Ce qui est déjà juste, en revanche, et qui ne bougera plus : les deux offres viennent du **même
 * catalogue que l'app**, et le pourcentage d'économie est **calculé** depuis les deux prix. La spec
 * annonçait « Économise 60 % » ; le chiffre juste sort du calcul, et il suivra le jour où un prix
 * bougera. Une remise annoncée à côté de deux prix qui la contredisent est une allégation
 * commerciale fausse, et sur un site elle est indexée.
 *
 * **La croix est visible tout de suite**, en haut à droite. Un paywall qui cache sa sortie se
 * referme par le bouton retour du navigateur, et ce qu'on gagne en insistance se paye en abandons.
 *
 * C'est aussi l'écran qui **déverse les réponses en base** : toutes les questions sont derrière, et
 * s'il y a une session, `profiles` et `exams` s'écrivent ici.
 */
export default function OfferStep() {
  const { answers, ready } = useOnboarding();
  const router = useRouter();
  const [saved, setSaved] = useState<SaveResult | null>(null);
  const [checkout, setCheckout] = useState<string | null>(null);

  useEffect(() => {
    if (!ready || saved) return;

    void saveOnboarding({
      country: answers.country,
      studyLevel: answers.studyLevel,
      subjects: answers.subjects,
      institutionId: answers.institutionId,
      institutionName: answers.institutionName,
      examDate: answers.examDate,
    }).then(setSaved);
    // Une seule fois, quand l'état lu du stockage est là.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ready]);

  const saving = pricing.savingsPercent();

  return (
    <div className="mx-auto w-full max-w-[560px] px-screen pb-10">
      <div className="flex h-14 items-center justify-end">
        <button
          type="button"
          aria-label="Fermer"
          onClick={() => router.push("/app")}
          className="pressable -mr-1 flex h-9 w-9 items-center justify-center rounded-full text-ink-tertiary"
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

      <h1 className="text-[27px] font-bold leading-[1.15] text-ink sm:text-[31px]">
        Ne rate pas l&apos;occasion de devenir le meilleur de ta classe.
      </h1>
      <p className="mt-3 text-[15px] text-ink-secondary">Débloque tout Micabo et arrive préparé.</p>

      <ul className="paper mt-7 divide-y divide-hairline overflow-hidden rounded-group bg-surface">
        {[
          "Quiz et cartes illimités",
          "Fiches générées et adaptées à ton niveau",
          "Révisions espacées, pour revoir au bon moment",
          "Mode examen : ton planning se réorganise autour de la date",
          "Suivi de progression, chapitre par chapitre",
          "Plus d'angoisse à l'approche des examens",
        ].map((line) => (
          <li key={line} className="flex items-center gap-3 px-4 py-3.5">
            <svg aria-hidden viewBox="0 0 20 20" className="h-4 w-4 shrink-0 text-accent">
              <path
                d="M4 10.5l4 4 8-9"
                fill="none"
                stroke="currentColor"
                strokeWidth="2.4"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
            <span className="text-[14.5px] text-ink">{line}</span>
          </li>
        ))}
      </ul>

      <div className="mt-5 space-y-2.5">
        {pricing.PLANS.map((plan) => {
          const recommended = plan.kind === pricing.RECOMMENDED_PLAN.kind;
          return (
            <button
              key={plan.kind}
              type="button"
              onClick={() => {
                void startCheckout(plan.kind).then((result) => {
                  if (result.status === "redirect" && result.url) {
                    window.location.href = result.url;
                    return;
                  }
                  setCheckout(result.message ?? "L'abonnement n'est pas encore ouvert.");
                });
              }}
              className={`pressable flex w-full items-center justify-between gap-4 rounded-group px-5 py-4 text-left ${
                recommended ? "bg-ink text-on-ink" : "paper bg-surface"
              }`}
            >
              <div>
                <p
                  className={`flex items-center gap-2 text-[15px] font-semibold ${
                    recommended ? "text-on-ink" : "text-ink"
                  }`}
                >
                  {plan.title}
                  {recommended ? (
                    <span className="rounded-pill bg-accent-vivid px-2 py-0.5 text-[10.5px] font-bold text-ink">
                      Économise {saving} %
                    </span>
                  ) : null}
                </p>
                <p
                  className={`mt-0.5 text-[13px] ${
                    recommended ? "text-on-ink-muted" : "text-ink-tertiary"
                  }`}
                >
                  {pricing.planCaption(plan)}
                </p>
              </div>
              <p
                className={`numeral shrink-0 text-xl font-bold ${
                  recommended ? "text-on-ink" : "text-ink"
                }`}
              >
                {pricing.priceText(plan.price)}
              </p>
            </button>
          );
        })}
      </div>

      {checkout ? (
        <p
          className="mt-4 rounded-button bg-surface-muted px-4 py-3 text-[13.5px] text-ink-secondary"
          role="status"
        >
          {checkout}
        </p>
      ) : null}

      <p className="mt-6 rounded-button bg-surface-muted px-4 py-3.5 text-[13.5px] leading-relaxed text-ink-secondary">
        L&apos;abonnement n&apos;est pas encore ouvert : il n&apos;y a rien à payer aujourd&apos;hui.
        En attendant, tu as{" "}
        <strong className="font-semibold text-ink">
          un cours entier, {Math.round(entitlement.FREE_TIER.readableSheetRatio * 100)} % de sa fiche
          et {entitlement.FREE_TIER.cardsPerSession} cartes par session
        </strong>
        .
      </p>

      <button
        type="button"
        onClick={() => router.push("/app")}
        className="pressable mt-5 h-14 w-full rounded-button bg-ink text-[16px] font-semibold text-on-ink"
      >
        Commencer avec le gratuit
      </button>

      <div className="mt-6 flex flex-wrap items-center justify-center gap-x-5 gap-y-2 text-[12.5px] text-ink-tertiary">
        {/* « Restaurer mes achats » est une notion iOS : sur le web, il n'y a rien à restaurer, il
            y a une session à ouvrir. */}
        <Link href="/commencer/compte" className="underline-draw">
          J&apos;ai déjà un abonnement
        </Link>
        <span>Conditions et confidentialité</span>
      </div>

      {saved?.status === "anonymous" ? (
        <p className="mt-6 text-center text-[12.5px] text-ink-tertiary">
          Tes réponses sont gardées sur cet appareil : elles rejoindront ton compte à la connexion.
        </p>
      ) : null}
    </div>
  );
}
