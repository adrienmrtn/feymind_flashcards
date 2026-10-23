"use client";

import { Suspense, useEffect, useState } from "react";
import type { Route } from "next";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";

import { useI18n } from "@/lib/i18n/client";
import { useLocalizedHref } from "@/lib/i18n/href";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { Field, FieldLabel } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { OrDivider, ProviderButton } from "@/components/auth/AuthButtons";
import { signInForAppStoreReview } from "@/lib/actions/app-store-review";
import { isAppStoreReviewEmail, isAppleAddress } from "@/lib/auth/app-store-review";
import { inspectAddress } from "@/lib/auth/email";
import { OFFER_PATH, safeAppPath } from "@/lib/auth/next-path";
import { oauthCallbackUrl, oauthFailureMessage } from "@/lib/auth/oauth";
import { PRIVACY_PATH, TERMS_PATH } from "@/lib/legal";
import { markPaywallPending, persistStoredAnswers } from "@/lib/onboarding/persist";
import { createClient } from "@/lib/supabase/client";
import { EmailSuggestion } from "@/components/auth/EmailSuggestion";

/**
 * La création du compte : **une vraie page**, posée à la **fin** du parcours.
 *
 * Les réponses sont déjà sur l'appareil. Ici on ouvre la session, on les déverse, et
 * **l'offre suit tout de suite** (`/commencer/offre`) : c'est le moment où l'étudiant vient de
 * dire ce qu'il vise. Elle se referme d'une croix, et l'app s'ouvre derrière.
 *
 * Apple et Google d'abord : un appui, aucun mot de passe à inventer. Le courriel
 * en dernier, parce qu'il demande d'aller lire une boîte. Le lien du courriel, le retour
 * d'Apple ou de Google ramènent tous trois à l'offre (`?next=/commencer/offre`).
 */
export default function AccountStep() {
  return (
    <Suspense fallback={null}>
      <AccountStepBody />
    </Suspense>
  );
}

type Pending = "apple" | "google" | "email" | null;

/** L'offre qui suit le compte. Le tableau de bord la reprendra si elle n'a pas été vue. */
const AFTER_ACCOUNT = OFFER_PATH;

/**
 * Où aller une fois la session ouverte : la `suite` demandée (une page de l'app qui renvoyait
 * ici faute de session), sinon l'offre. `markPaywallPending` garde l'offre en réserve pour le
 * tableau de bord, au cas où l'étudiant n'y passerait pas.
 */
function destination(suite: string | null): string {
  markPaywallPending();
  // `suite` vient de l'URL : `safeAppPath` n'y laisse passer qu'une page de l'app, jamais un
  // `/\autre-site` que le navigateur relirait comme une autre origine.
  return safeAppPath(suite, AFTER_ACCOUNT);
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
      router.replace(destination(params.get("suite")) as Route);
    });
  }, [params, router]);

  function callbackUrl() {
    return oauthCallbackUrl(destination(params.get("suite")));
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
      setFailure(oauthFailureMessage(t, provider, error.message));
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

    // Le compte de relecture s'ouvre côté serveur : le mot de passe ne quitte jamais
    // `APP_STORE_REVIEW_PASSWORD`. Une autre adresse d'Apple ne reçoit pas de lien
    // non plus - il rebondirait - mais elle n'ouvre rien.
    if (isAppleAddress(address)) {
      if (!isAppStoreReviewEmail(address)) {
        setPending(null);
        setFailure(t("onboarding.emailUndeliverable"));
        return;
      }
      const result = await signInForAppStoreReview(address);
      setPending(null);
      if (result.status === "error") {
        setFailure(result.message);
        return;
      }
      await persistStoredAnswers();
      router.replace(destination(params.get("suite")) as Route);
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

  // La carte a la même hauteur sur tous les écrans, et cette page-ci doit tenir dedans sans
  // ascenseur : c'est celle où l'on s'engage, et une page qui défile à ce moment-là cache la
  // moitié des façons de créer un compte. Un titre, deux boutons, un champ, la mention légale.
  return (
    <div className="flex min-h-0 flex-1 flex-col overflow-y-auto px-6 py-6 sm:px-10 sm:py-8">
      <div className="step-part mx-auto my-auto w-full max-w-[400px]">
        <Link
          href={"/commencer/parcours" as Route}
          className="pressable -ms-1 mb-3 inline-flex min-h-10 items-center gap-1.5 rounded-pill pe-2 text-[14.5px] font-semibold text-ink-tertiary transition-colors duration-hover hover:text-ink"
        >
          <svg aria-hidden viewBox="0 0 20 20" className="h-4 w-4 rtl:-scale-x-100">
            <path d="M12 4l-6 6 6 6" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
          {t("common.back")}
        </Link>
        <h1 className="text-balance text-center text-[26px] font-extrabold leading-[1.12] tracking-tight-title text-ink sm:text-[29px]">
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
                className="h-12 rounded-[14px] text-[16px] sm:text-[16px] [&_[data-slot=input]]:h-12 [&_[data-slot=input]]:text-[16px] [&_[data-slot=input]]:leading-[3rem]"
              />
            </Field>
            <Button
              type="submit"
              size="xl"
              loading={pending === "email"}
              disabled={email.trim().length === 0}
              className="h-12 w-full rounded-[14px] text-[15.5px] font-extrabold sm:h-12 sm:text-[15.5px]"
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

        <p className="mt-6 text-center text-[12px] leading-relaxed text-ink-tertiary">
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
