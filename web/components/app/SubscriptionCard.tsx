"use client";

import { useState, useTransition } from "react";

import { ROW_BUTTON, SettingsRow } from "@/components/app/settings/Rows";
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
    <SettingsRow
      label={t("app.settings.subscription")}
      hint={
        <>
          <span className="font-medium text-ink">{headline}</span>
          {plan && view.paid ? <span> · {plan}</span> : null}
          <br />
          {subscriptionDetail(t, locale, view)}
          {failure ? (
            <>
              <br />
              <span className="text-negative" role="alert">
                {failure}
              </span>
            </>
          ) : null}
        </>
      }
      control={
        action ? (
          <button type="button" onClick={run} disabled={pending} className={ROW_BUTTON}>
            {pending ? t("app.subscription.opening") : action}
          </button>
        ) : null
      }
    />
  );
}
