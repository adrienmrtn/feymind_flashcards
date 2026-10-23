"use client";

import { Suspense, useState } from "react";
import type { Route } from "next";
import Link from "next/link";
import { useRouter } from "next/navigation";

import { AppearanceSwitcher } from "@/components/appearance/AppearanceSwitcher";
import { BrandLockup } from "@/components/BrandMark";
import { LanguageSwitcher } from "@/components/i18n/LanguageSwitcher";
import { useI18n } from "@/lib/i18n/client";
import { useLocalizedHref } from "@/lib/i18n/href";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { Field, FieldLabel } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { OrDivider, ProviderButton } from "@/components/auth/AuthButtons";
import { Atmosphere } from "@/components/landing/Atmosphere";
import { Mika } from "@/components/mika/Mika";
import {
  APP_STORE_REVIEW_EMAIL,
  APP_STORE_REVIEW_PASSWORD,
  isAppStoreReviewEmail,
} from "@/lib/auth/app-store-review";
import { inspectAddress } from "@/lib/auth/email";
import { oauthCallbackUrl, oauthFailureMessage } from "@/lib/auth/oauth";
import { PRIVACY_PATH, TERMS_PATH } from "@/lib/legal";
import { createClient } from "@/lib/supabase/client";
import { EmailSuggestion } from "@/components/auth/EmailSuggestion";

/**
 * La porte de ceux qui ont déjà un compte.
 *
 * Apple, Google, ou un lien. Après l'échange, on ouvre l'app : la session
 * Supabase *est* le compte. On ne recréera plus un parcours par-dessus.
 *
 * Une carte centrée sur le lavage de la vitrine, Mika perché dessus : Apple et Google en
 * haut, « ou », l'adresse, le bouton, le lien vers l'inscription et la ligne des conditions.
 * Les mêmes trois portes que dans l'app, dans le même ordre. La carte est une surface du
 * thème : blanche le jour, sombre la nuit.
 */
export default function ConnexionPage() {
  return (
    <Suspense fallback={null}>
      <ConnexionBody />
    </Suspense>
  );
}

type Pending = "apple" | "google" | "email" | null;

function ConnexionBody() {
  const { t } = useI18n();
  const homeHref = useLocalizedHref("/");
  const termsHref = useLocalizedHref(TERMS_PATH);
  const privacyHref = useLocalizedHref(PRIVACY_PATH);
  const router = useRouter();
  const [pending, setPending] = useState<Pending>(null);
  const [email, setEmail] = useState("");
  const [sent, setSent] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const [suggestion, setSuggestion] = useState<{ typed: string; corrected: string } | null>(null);

  function callbackUrl() {
    return oauthCallbackUrl("/app");
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
   * Un lien envoyé à une boîte qui n'existe pas revient, et ce rebond est compté contre
   * l'envoyeur mutualisé qu'on partage avec tous les projets Supabase. Une faute de frappe
   * coûte donc plus qu'un élève qui attend : elle grignote le droit d'envoyer.
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
      router.replace("/app" as Route);
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

  return (
    <div className="lp relative isolate flex min-h-svh flex-col overflow-hidden">
      <Atmosphere boxed />

      <header className="mx-auto flex w-full max-w-page items-center justify-between gap-3 px-screen py-4">
        <BrandLockup
          href={homeHref}
          size={28}
          className="text-ink"
          wordClassName="text-[15px] font-bold text-ink"
        />
        <div className="flex items-center gap-1.5">
          <AppearanceSwitcher variant="compact" />
          <LanguageSwitcher />
        </div>
      </header>

      <main id="contenu" className="flex flex-1 items-center justify-center px-3 pb-12 pt-16 sm:px-6">
        <div className="lp-enter relative w-full max-w-[440px]">
          {/* Mika, perché sur le bord de la carte, comme sur la carte de la vitrine. */}
          <div aria-hidden className="absolute left-1/2 top-[-66px] z-10 w-[72px] -translate-x-1/2">
            <Mika mood="wave" label="" />
          </div>

          <div className="lp-demo-card rounded-[28px] bg-surface px-6 pb-7 pt-9 sm:px-9 sm:pb-9 sm:pt-11">
            <h1 className="text-balance text-center text-[26px] font-extrabold leading-[1.12] tracking-tight-title text-ink sm:text-[28px]">
              {t("onboarding.connexionTitle")}
            </h1>
            <p className="mx-auto mt-2.5 max-w-[34ch] text-center text-[14.5px] leading-relaxed text-ink-secondary">
              {t("onboarding.connexionSubtitle")}
            </p>

            <div className="mt-7 space-y-2.5">
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
              <form onSubmit={sendLink} className="space-y-3">
                <Field>
                  <FieldLabel className="text-[13.5px] font-bold text-ink">
                    {t("onboarding.emailLabel")}
                  </FieldLabel>
                  <Input
                    id="login-email"
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

            <p className="mt-6 text-center text-[14px] text-ink-secondary">
              {t("onboarding.noAccount")}{" "}
              <Link href="/commencer" className="underline-draw font-bold text-accent">
                {t("onboarding.createIt")}
              </Link>
            </p>
          </div>

          <p className="mx-auto mt-6 max-w-[40ch] text-center text-[12.5px] leading-relaxed text-ink-tertiary">
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
      </main>
    </div>
  );
}
