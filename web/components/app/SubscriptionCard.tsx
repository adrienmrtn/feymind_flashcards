"use client";

import { useState, useTransition } from "react";

import { manageSubscription } from "@/lib/actions/checkout";
import { requestPaywall } from "@/lib/paywall";
import {
  manageLabel,
  planTitleFor,
  subscriptionDetail,
  subscriptionHeadline,
  type SubscriptionView,
} from "@/lib/subscription-copy";

/**
 * L'abonnement, **en tête des réglages**.
 *
 * Le serveur sait déjà ouvrir le bon magasin. Sans cette carte, le bouton
 * n'existait nulle part : on allait le chercher dans le code.
 */
export function SubscriptionCard(view: SubscriptionView) {
  const [pending, startTransition] = useTransition();
  const [failure, setFailure] = useState<string | null>(null);

  const action = manageLabel(view);
  const plan = planTitleFor(view.productId);
  const headline = subscriptionHeadline(view);

  function run() {
    if (!action || pending) return;
    setFailure(null);

    if (!view.paid) {
      requestPaywall();
      return;
    }

    startTransition(async () => {
      const result = await manageSubscription();
      if (result.status === "redirect" && result.url) {
        window.location.href = result.url;
        return;
      }
      setFailure(result.message ?? "Le portail n'a pas pu s'ouvrir.");
    });
  }

  return (
    <section id="abonnement" className="saas-card scroll-mt-6 px-7 py-7">
      <p className="text-[15px] font-semibold text-ink">Abonnement</p>
      <p className="mt-1.5 text-[13.5px] font-medium text-ink">
        {headline}
        {plan && view.paid ? (
          <span className="font-normal text-ink-tertiary"> · {plan}</span>
        ) : null}
      </p>
      <p className="mt-1.5 max-w-[48ch] text-[13.5px] leading-relaxed text-ink-secondary">
        {subscriptionDetail(view)}
      </p>

      {action ? (
        <button
          type="button"
          onClick={run}
          disabled={pending}
          className="pressable mt-5 rounded-button bg-accent px-4 py-2.5 text-[14px] font-semibold text-on-ink disabled:opacity-40"
        >
          {pending ? "Ouverture…" : action}
        </button>
      ) : null}

      {failure ? (
        <p className="mt-3 text-[13px] text-negative" role="alert">
          {failure}
        </p>
      ) : null}
    </section>
  );
}
