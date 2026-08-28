"use client";

import { Suspense, useState } from "react";
import Link from "next/link";

import { SoftMesh } from "@/components/atmosphere/SoftAtmosphere";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { Field, FieldLabel } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { Separator } from "@/components/ui/separator";
import { PRIVACY_PATH, TERMS_PATH } from "@/lib/legal";
import { createClient } from "@/lib/supabase/client";

/**
 * La porte de ceux qui ont déjà un compte.
 *
 * Apple, Google, ou un lien. Après l'échange, on ouvre l'app : la session
 * Supabase *est* le compte. On ne recréera plus un parcours par-dessus.
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
  const [pending, setPending] = useState<Pending>(null);
  const [email, setEmail] = useState("");
  const [sent, setSent] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);

  function callbackUrl() {
    return `${window.location.origin}/auth/callback?next=${encodeURIComponent("/app")}`;
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
      setFailure(error.message);
    }
  }

  async function sendLink(event: React.FormEvent) {
    event.preventDefault();
    setFailure(null);
    setPending("email");

    const supabase = createClient();
    const { error } = await supabase.auth.signInWithOtp({
      email: email.trim(),
      options: { emailRedirectTo: callbackUrl() },
    });

    setPending(null);
    if (error) setFailure(error.message);
    else setSent(true);
  }

  return (
    <div className="relative mx-auto flex min-h-svh w-full max-w-[440px] flex-col justify-center px-screen py-12">
      <SoftMesh />
      <div className="relative">
        <Link href="/" className="text-[15px] font-bold text-ink">
          Micabo
        </Link>

        <h1 className="mt-8 text-[32px] font-bold leading-[1.08] tracking-display text-ink sm:text-[38px]">
          Content de te revoir.
        </h1>
        <p className="mt-3 text-[15px] text-ink-secondary">
          Connecte-toi pour retrouver tes cours, tes cartes et ta série.
        </p>

        <div className="mt-8 space-y-2.5">
          <ProviderButton
            label="Continuer avec Apple"
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
            label="Continuer avec Google"
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
          <span className="text-[12px] text-ink-tertiary">ou</span>
          <Separator className="flex-1" />
        </div>

        {sent ? (
          <Alert variant="success" className="rise" role="status">
            <AlertDescription className="text-[14.5px] font-medium text-accent">
              Ouvre le lien envoyé à {email.trim()}
            </AlertDescription>
          </Alert>
        ) : (
          <form onSubmit={sendLink} className="space-y-2.5">
            <Field>
              <FieldLabel className="sr-only">Ton adresse électronique</FieldLabel>
              <Input
                id="login-email"
                type="email"
                inputMode="email"
                autoComplete="email"
                required
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                placeholder="ton@adresse.fr"
                className="h-14 rounded-button text-[16px] sm:text-[16px] [&_[data-slot=input]]:h-14 [&_[data-slot=input]]:text-[16px] [&_[data-slot=input]]:leading-[3.5rem]"
              />
            </Field>
            <Button
              type="submit"
              variant="outline"
              size="xl"
              loading={pending === "email"}
              disabled={email.trim().length === 0}
              className="btn-rise shiny h-14 w-full text-[16px] hover:bg-transparent sm:h-14 sm:text-[16px]"
            >
              Recevoir un lien
            </Button>
          </form>
        )}

        {failure ? (
          <Alert variant="error" className="mt-3">
            <AlertDescription className="text-[13.5px] text-negative">{failure}</AlertDescription>
          </Alert>
        ) : null}

        <p className="mt-8 text-[12.5px] leading-relaxed text-ink-tertiary">
          En continuant, tu acceptes les{" "}
          <Link href={TERMS_PATH} className="underline-draw text-ink-secondary">
            conditions d&apos;utilisation
          </Link>{" "}
          et la{" "}
          <Link href={PRIVACY_PATH} className="underline-draw text-ink-secondary">
            politique de confidentialité
          </Link>
          .
        </p>

        <p className="mt-6 text-[13.5px] text-ink-tertiary">
          Pas encore de compte ?{" "}
          <Link href="/commencer/pays" className="underline-draw font-medium text-ink">
            Créons-le
          </Link>
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
