"use client";

import { Suspense, useState } from "react";
import { useSearchParams } from "next/navigation";
import { ThinkingOrb } from "thinking-orbs";

import { Scaffold } from "@/components/onboarding/Scaffold";
import { SITE_URL } from "@/lib/config";
import { createClient } from "@/lib/supabase/client";

/**
 * La création du compte, au deuxième écran.
 *
 * **Trois voies, dans cet ordre, et l'ordre est un choix.** Apple et Google d'abord : elles se
 * font en un appui et sans mot de passe à inventer. Le courriel en dernier, parce qu'il demande
 * d'aller lire une boîte — et parce qu'il ne marchera pas avant qu'un vrai envoyeur soit branché
 * sur le projet. Son échec ne bloque donc personne, ce qui est la seule raison de le laisser là.
 *
 * Le compte est ici et pas à la fin : le tunnel iOS a dix-sept écrans pour donner une raison d'en
 * créer un, le web n'en a pas un. Et la règle de l'abonnement veut qu'on ne vende jamais avant la
 * connexion — le paywall est le dernier écran.
 */
export default function AccountStep() {
  return (
    <Suspense fallback={null}>
      <AccountStepBody />
    </Suspense>
  );
}

type Pending = "apple" | "google" | "email" | null;

function AccountStepBody() {
  const params = useSearchParams();
  const [pending, setPending] = useState<Pending>(null);
  const [email, setEmail] = useState("");
  const [sent, setSent] = useState(false);
  const [failure, setFailure] = useState<string | null>(params.get("erreur"));

  const next = "/commencer/pays";

  async function signInWith(provider: "apple" | "google") {
    setFailure(null);
    setPending(provider);

    const supabase = createClient();
    const { error } = await supabase.auth.signInWithOAuth({
      provider,
      options: {
        redirectTo: `${SITE_URL}/auth/callback?next=${encodeURIComponent(next)}`,
      },
    });

    // Un fournisseur éteint côté serveur le dit dans son message d'erreur, ce qui est plus utile
    // qu'un bouton absent dont personne ne peut deviner la cause.
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
      options: { emailRedirectTo: `${SITE_URL}/auth/callback?next=${encodeURIComponent(next)}` },
    });

    setPending(null);
    if (error) setFailure(error.message);
    else setSent(true);
  }

  return (
    <Scaffold
      eyebrow="Le parcours"
      title="Crée ton compte"
      subtitle="Un appui, et on enchaîne. Un écran à la fois."
      footer={
        <p className="text-center text-[12.5px] leading-relaxed text-ink-tertiary">
          En continuant, tu acceptes les conditions d&apos;utilisation et la politique de
          confidentialité.
        </p>
      }
    >
      <div className="space-y-2.5">
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

        <div className="flex items-center gap-3 py-3">
          <span className="h-px flex-1 bg-hairline-on-canvas" />
          <span className="text-[12px] text-ink-tertiary">ou</span>
          <span className="h-px flex-1 bg-hairline-on-canvas" />
        </div>

        {sent ? (
          <p className="rounded-button bg-accent-soft px-4 py-3.5 text-[14px] font-medium text-accent">
            Ouvre le lien envoyé à {email.trim()}.
          </p>
        ) : (
          <form onSubmit={sendLink} className="paper flex items-center gap-2 rounded-button bg-surface p-1.5">
            <label htmlFor="onboarding-email" className="sr-only">
              Ton adresse électronique
            </label>
            <input
              id="onboarding-email"
              type="email"
              inputMode="email"
              autoComplete="email"
              required
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              placeholder="ton@adresse.fr"
              className="min-w-0 flex-1 bg-transparent px-3 text-[16px] text-ink outline-none placeholder:text-ink-tertiary"
            />
            <button
              type="submit"
              disabled={pending === "email"}
              className="pressable h-10 shrink-0 rounded-[12px] bg-surface-muted px-4 text-[14px] font-semibold text-ink disabled:opacity-70"
            >
              {pending === "email" ? <ThinkingOrb state="connecting" size={20} /> : "Recevoir un lien"}
            </button>
          </form>
        )}

        {failure ? (
          <p className="rounded-button bg-negative-soft px-4 py-3 text-[13.5px] text-negative" role="alert">
            {failure}
          </p>
        ) : null}
      </div>
    </Scaffold>
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
    <button
      type="button"
      onClick={onPress}
      disabled={pending}
      className={`pressable flex h-14 w-full items-center justify-center gap-3 rounded-button text-[16px] font-semibold disabled:opacity-70 ${
        dark ? "bg-ink text-on-ink" : "paper bg-surface text-ink"
      }`}
    >
      {pending ? <ThinkingOrb state="connecting" size={20} theme={dark ? "dark" : "light"} /> : icon}
      {label}
    </button>
  );
}
