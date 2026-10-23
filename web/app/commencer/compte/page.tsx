"use client";

import { Suspense, useEffect, useState } from "react";
import type { Route } from "next";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";

import { BrandLockup } from "@/components/BrandMark";
import { LanguageSwitcher } from "@/components/i18n/LanguageSwitcher";
import { useI18n } from "@/lib/i18n/client";
import { useLocalizedHref } from "@/lib/i18n/href";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { Field, FieldLabel } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { OrDivider, ProviderButton } from "@/components/auth/AuthButtons";
import {
  APP_STORE_REVIEW_EMAIL,
  APP_STORE_REVIEW_PASSWORD,
  isAppStoreReviewEmail,
} from "@/lib/auth/app-store-review";
import { inspectAddress } from "@/lib/auth/email";
import { oauthCallbackUrl, oauthFailureMessage } from "@/lib/auth/oauth";
import { PRIVACY_PATH, TERMS_PATH } from "@/lib/legal";
import { markPaywallPending, persistStoredAnswers } from "@/lib/onboarding/persist";
import { createClient } from "@/lib/supabase/client";
import { EmailSuggestion } from "@/components/auth/EmailSuggestion";

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

function destination(): string {
  markPaywallPending();
  return "/app";
}

function AccountStepBody() {
  const { t } = useI18n();
  const termsHref = useLocalizedHref(TERMS_PATH);
  const privacyHref = useLocalizedHref(PRIVACY_PATH);
  const params = useSearchParams();
  const router = useRouter();
  const [pending, setPending] = useState<Pending>(null);
  const [email, setEmail] = useState("");
  const [sent, setSent] = useState(false);
  const [failure, setFailure] = useState<string | null>(params.get("erreur"));
  const [suggestion, setSuggestion] = useState<{ typed: string; corrected: string } | null>(null);

  useEffect(() => {
    const supabase = createClient();
    void supabase.auth.getUser().then(async ({ data }) => {
      if (!data.user) return;
      await persistStoredAnswers();
      const suite = params.get("suite");
      const next =
        suite && suite.startsWith("/") && !suite.startsWith("//")
          ? suite
          : destination();
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

  /**
   * Le lien part **une fois l'adresse relue**.
   *
   * C'est ici que ça compte le plus : à la création du compte, personne n'a encore de
   * session, donc une adresse ratée n'est pas un lien perdu - c'est un compte qui n'existera
   * jamais, et un rebond de plus sur l'envoyeur mutualisé de Supabase.
   */
  async function sendLink(event: React.FormEvent) {
    event.preventDefault();
    setFailure(null);

    const verdict = inspectAddress(email);

    if (verdict.kind === "malformed") {
      setSuggestion(null);
      setFailure(t("onboarding.emailMalformed"));
      return;
    }

    if (verdict.kind === "undeliverable") {
      setSuggestion(null);
      setFailure(t("onboarding.emailUndeliverable"));
      return;
    }

    if (verdict.kind === "suspicious") {
      setSuggestion({ typed: verdict.address, corrected: verdict.suggestion });
      return;
    }

    await deliver(verdict.address);
  }

  async function deliver(address: string) {
    setFailure(null);
    setSuggestion(null);
    setPending("email");

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
      router.replace(destination() as Route);
      router.refresh();
      return;
    }

    const { error } = await supabase.auth.signInWithOtp({
      email: address,
      options: { emailRedirectTo: callbackUrl() },
    });

    setPending(null);
    if (error) setFailure(error.message);
    else {
      setEmail(address);
      setSent(true);
    }
  }

  // La carte fait 760 px de haut sur tous les écrans, et cette page-ci doit tenir dedans sans
  // ascenseur : c'est la dernière du parcours, celle où l'on s'engage, et une page qui défile à
  // ce moment-là cache la moitié des façons de créer un compte. Tout y est donc réglé au plus
  // serré - un titre, deux boutons, un champ, la mention légale - et elle se centre.
  return (
    <div className="flex min-h-0 flex-1 flex-col overflow-y-auto px-6 py-6 sm:px-10 sm:py-8">
      <div className="rise mx-auto my-auto w-full max-w-[400px]">
        <div className="flex items-center justify-between gap-3">
          <BrandLockup
            href="/commencer/parcours"
            size={28}
            className="text-ink"
            wordClassName="text-[15px] font-bold text-ink"
          />
          <LanguageSwitcher />
        </div>

        <h1 className="mt-7 text-[28px] font-bold leading-[1.1] tracking-display text-ink sm:text-[32px] text-balance">
          {t("onboarding.compteTitle")}
        </h1>

        <div className="mt-6 space-y-2.5">
          <ProviderButton
            provider="apple"
            label={t("onboarding.continueApple")}
            pending={pending === "apple"}
            onPress={() => signInWith("apple")}
          />
          <ProviderButton
            provider="google"
            label={t("onboarding.continueGoogle")}
            pending={pending === "google"}
            onPress={() => signInWith("google")}
          />
        </div>

        <OrDivider label={t("onboarding.or")} />

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
                onChange={(event) => {
                  setEmail(event.target.value);
                  setSuggestion(null);
                  setFailure(null);
                }}
                placeholder={t("onboarding.emailPlaceholder")}
                className="h-12 rounded-button text-[16px] sm:text-[16px] [&_[data-slot=input]]:h-12 [&_[data-slot=input]]:text-[16px] [&_[data-slot=input]]:leading-[3rem]"
              />
            </Field>
            <Button
              type="submit"
              size="xl"
              loading={pending === "email"}
              disabled={email.trim().length === 0}
              className="h-12 w-full text-[16px] sm:h-12 sm:text-[16px]"
            >
              {t("onboarding.sendLink")}
            </Button>
          </form>
        )}

        {suggestion ? (
          <EmailSuggestion
            typed={suggestion.typed}
            corrected={suggestion.corrected}
            onAccept={() => void deliver(suggestion.corrected)}
            onKeep={() => void deliver(suggestion.typed)}
          />
        ) : null}

        {failure ? (
          <Alert variant="error" className="mt-3">
            <AlertDescription className="text-[13.5px] text-negative">{failure}</AlertDescription>
          </Alert>
        ) : null}

        <p className="mt-6 text-[12px] leading-relaxed text-ink-tertiary">
          {t("onboarding.legalPrefix")}{" "}
          <Link href={termsHref} className="underline-draw text-ink-secondary">
            {t("onboarding.legalTerms")}
          </Link>{" "}
          {t("onboarding.legalAnd")}{" "}
          <Link href={privacyHref} className="underline-draw text-ink-secondary">
            {t("onboarding.legalPrivacy")}
          </Link>
          .
        </p>
      </div>
    </div>
  );
}
