"use client";

import { useState, useTransition } from "react";

import { manageSubscription } from "@/lib/actions/checkout";
import { useI18n } from "@/lib/i18n/client";
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
 */
export function SubscriptionCard(view: SubscriptionView) {
  const [pending, startTransition] = useTransition();
  const [failure, setFailure] = useState<string | null>(null);
  const { t, locale } = useI18n();

  const action = manageLabel(t, view);
  const plan = planTitleFor(t, view.productId);
  const headline = subscriptionHeadline(t, view);

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
      setFailure(result.message ?? t("app.subscription.portalError"));
    });
  }

  return (
    <section id="abonnement" className="saas-card scroll-mt-6 px-7 py-7">
      <p className="text-[15px] font-semibold text-ink">{t("app.settings.subscription")}</p>
      <p className="mt-1.5 text-[13.5px] font-medium text-ink">
        {headline}
        {plan && view.paid ? (
          <span className="font-normal text-ink-tertiary"> · {plan}</span>
        ) : null}
      </p>
      <p className="mt-1.5 max-w-[48ch] text-[13.5px] leading-relaxed text-ink-secondary">
        {subscriptionDetail(t, locale, view)}
      </p>

      {action ? (
        <button
          type="button"
          onClick={run}
          disabled={pending}
          className="pressable mt-5 rounded-button bg-accent px-4 py-2.5 text-[14px] font-semibold text-on-ink disabled:opacity-40"
        >
          {pending ? t("app.subscription.opening") : action}
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
