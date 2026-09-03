"use client";

import { Suspense, useEffect, useState } from "react";
import type { Route } from "next";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";

import { BrandLockup } from "@/components/BrandMark";
import { LanguageSwitcher } from "@/components/i18n/LanguageSwitcher";
import { useI18n } from "@/lib/i18n/client";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { Field, FieldLabel } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { Separator } from "@/components/ui/separator";
import {
  APP_STORE_REVIEW_EMAIL,
  APP_STORE_REVIEW_PASSWORD,
  isAppStoreReviewEmail,
} from "@/lib/auth/app-store-review";
import { oauthCallbackUrl, oauthFailureMessage } from "@/lib/auth/oauth";
import { PRIVACY_PATH, TERMS_PATH } from "@/lib/legal";
import { markPaywallPending, persistStoredAnswers } from "@/lib/onboarding/persist";
import { createClient } from "@/lib/supabase/client";

/**
 * La création du compte : **une vraie page**, posée à la **fin** du parcours.
 *
 * Les réponses sont déjà sur l'appareil. Ici on ouvre la session, on les déverse,
 * et on entre dans l'app. Le paywall n'est pas ici : il se posera sur le tableau
 * de bord, une fois qu'on a vu l'étagère.
 *
 * Apple et Google d'abord : un appui, aucun mot de passe à inventer. Le courriel
 * en dernier, parce qu'il demande d'aller lire une boîte.
 */
export default function AccountStep() {
  return (
    <Suspense fallback={null}>
      <AccountStepBody />
    </Suspense>
  );
}

type Pending = "apple" | "google" | "email" | null;

function destination(email?: string | null): string {
  if (!isAppStoreReviewEmail(email)) {
    markPaywallPending();
  }
  return "/app";
}

function AccountStepBody() {
  const { t } = useI18n();
  const params = useSearchParams();
  const router = useRouter();
  const [pending, setPending] = useState<Pending>(null);
  const [email, setEmail] = useState("");
  const [sent, setSent] = useState(false);
  const [failure, setFailure] = useState<string | null>(params.get("erreur"));

  useEffect(() => {
    const supabase = createClient();
    void supabase.auth.getUser().then(async ({ data }) => {
      if (!data.user) return;
      await persistStoredAnswers();
      const suite = params.get("suite");
      const next =
        suite && suite.startsWith("/") && !suite.startsWith("//")
          ? suite
          : destination(data.user.email);
      router.replace(next as Route);
    });
  }, [params, router]);

  function callbackUrl() {
    return oauthCallbackUrl(destination());
  }

  async function signInWith(provider: "apple" | "google") {
    setFailure(null);
    setPending(provider);

    const supabase = createClient();
    const { error } = await supabase.auth.signInWithOAuth({
      provider,
      options: { redirectTo: callbackUrl() },
    });

    if (error) {
      setPending(null);
      setFailure(oauthFailureMessage(provider, error.message));
    }
  }

  async function sendLink(event: React.FormEvent) {
    event.preventDefault();
    setFailure(null);
    setPending("email");

    const address = email.trim();
    const supabase = createClient();

    if (isAppStoreReviewEmail(address)) {
      const { error } = await supabase.auth.signInWithPassword({
        email: APP_STORE_REVIEW_EMAIL,
        password: APP_STORE_REVIEW_PASSWORD,
      });
      setPending(null);
      if (error) {
        setFailure(error.message);
        return;
      }
      await persistStoredAnswers();
      router.replace(destination(address) as Route);
      router.refresh();
      return;
    }

    const { error } = await supabase.auth.signInWithOtp({
      email: address,
      options: { emailRedirectTo: callbackUrl() },
    });

    setPending(null);
    if (error) setFailure(error.message);
    else setSent(true);
  }

  return (
    <div className="flex min-h-0 flex-1 flex-col overflow-y-auto px-6 py-6 sm:px-10 sm:py-8">
      <div className="rise mx-auto w-full max-w-[400px]">
        <div className="flex items-center justify-between gap-3">
          <BrandLockup
            href="/commencer/parcours"
            size={28}
            className="text-ink"
            wordClassName="text-[15px] font-bold text-ink"
          />
          <LanguageSwitcher />
        </div>

        <h1 className="mt-8 text-[32px] font-bold leading-[1.08] tracking-display text-ink sm:text-[38px] text-balance">
          {t("onboarding.compteTitle")}
        </h1>
        <p className="mt-3 text-[15px] text-ink-secondary">
          {t("onboarding.compteSubtitle")}
        </p>

        <div className="mt-8 space-y-2.5">
          <ProviderButton
            label={t("onboarding.continueApple")}
            dark
            pending={pending === "apple"}
            onPress={() => signInWith("apple")}
            icon={
              <svg aria-hidden viewBox="0 0 24 24" className="h-5 w-5" fill="currentColor">
                <path d="M16.5 12.6c0-2 1.6-3 1.7-3.1-.9-1.4-2.4-1.5-2.9-1.6-1.2-.1-2.4.7-3 .7-.6 0-1.6-.7-2.6-.7-1.3 0-2.6.8-3.3 2-1.4 2.4-.4 6 1 7.9.7.9 1.5 2 2.5 2 1 0 1.3-.6 2.5-.6s1.5.6 2.5.6 1.7-.9 2.4-1.9c.5-.7.7-1.1.9-1.6-2.3-.9-2.2-3.6-2.2-3.7zM14.6 5.9c.5-.6.9-1.5.8-2.4-.8 0-1.7.5-2.3 1.2-.5.6-.9 1.5-.8 2.3.9.1 1.8-.4 2.3-1.1z" />
              </svg>
            }
          />

          <ProviderButton
            label={t("onboarding.continueGoogle")}
            pending={pending === "google"}
            onPress={() => signInWith("google")}
            icon={
              <svg aria-hidden viewBox="0 0 24 24" className="h-5 w-5">
                <path
                  fill="#4285F4"
                  d="M23 12.2c0-.8-.1-1.6-.2-2.3H12v4.4h6.2a5.3 5.3 0 0 1-2.3 3.5v2.9h3.7c2.2-2 3.4-5 3.4-8.5z"
                />
                <path
                  fill="#34A853"
                  d="M12 23.5c3 0 5.5-1 7.3-2.7l-3.6-2.8a6.9 6.9 0 0 1-10.3-3.6H1.6v3A11.5 11.5 0 0 0 12 23.5z"
                />
                <path fill="#FBBC05" d="M5.4 14.4a6.9 6.9 0 0 1 0-4.4v-3H1.6a11.5 11.5 0 0 0 0 10.4z" />
                <path
                  fill="#EA4335"
                  d="M12 5.4c1.6 0 3.1.6 4.2 1.7l3.2-3.2A11.5 11.5 0 0 0 1.6 7l3.8 3a6.9 6.9 0 0 1 6.6-4.6z"
                />
              </svg>
            }
          />
        </div>

        <div className="my-6 flex items-center gap-3">
          <Separator className="flex-1" />
          <span className="text-[12px] text-ink-tertiary">{t("onboarding.or")}</span>
          <Separator className="flex-1" />
        </div>

        {sent ? (
          <Alert variant="success" className="rise" role="status">
            <AlertDescription className="text-[14.5px] font-medium text-accent">
              {t("onboarding.linkSent", { email: email.trim() })}
            </AlertDescription>
          </Alert>
        ) : (
          <form onSubmit={sendLink} className="space-y-2.5">
            <Field>
              <FieldLabel className="sr-only">{t("onboarding.emailLabel")}</FieldLabel>
              <Input
                id="signup-email"
                type="email"
                inputMode="email"
                autoComplete="email"
                required
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                placeholder={t("onboarding.emailPlaceholder")}
                className="h-14 rounded-button text-[16px] sm:text-[16px] [&_[data-slot=input]]:h-14 [&_[data-slot=input]]:text-[16px] [&_[data-slot=input]]:leading-[3.5rem]"
              />
            </Field>
            <Button
              type="submit"
              size="xl"
              loading={pending === "email"}
              disabled={email.trim().length === 0}
              className="h-14 w-full text-[16px] sm:h-14 sm:text-[16px]"
            >
              {t("onboarding.sendLink")}
            </Button>
          </form>
        )}

        {failure ? (
          <Alert variant="error" className="mt-3">
            <AlertDescription className="text-[13.5px] text-negative">{failure}</AlertDescription>
          </Alert>
        ) : null}

        <p className="mt-8 text-[12.5px] leading-relaxed text-ink-tertiary">
          {t("onboarding.legalPrefix")}{" "}
          <Link href={TERMS_PATH} className="underline-draw text-ink-secondary">
            {t("onboarding.legalTerms")}
          </Link>{" "}
          {t("onboarding.legalAnd")}{" "}
          <Link href={PRIVACY_PATH} className="underline-draw text-ink-secondary">
            {t("onboarding.legalPrivacy")}
          </Link>
          .
        </p>
      </div>
    </div>
  );
}

function ProviderButton({
  label,
  icon,
  dark = false,
  pending,
  onPress,
}: {
  label: string;
  icon: React.ReactNode;
  dark?: boolean;
  pending: boolean;
  onPress: () => void;
}) {
  return (
    <Button
      type="button"
      size="xl"
      variant={dark ? "default" : "outline"}
      loading={pending}
      onClick={onPress}
      className={`h-14 w-full text-[16px] sm:h-14 sm:text-[16px] ${
        dark ? "shiny" : "btn-fill hover:bg-transparent"
      }`}
    >
      {icon}
      {label}
    </Button>
  );
}
