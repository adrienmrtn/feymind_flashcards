"use client";

import { Button } from "@/components/ui/button";

/**
 * **Les boutons de connexion, dessinés une fois** pour la connexion et la création du compte.
 *
 * Apple d'abord, en encre pleine (noir le jour, clair la nuit, comme le veut Apple), Google
 * ensuite sur une surface bordée, puis le courriel. C'est l'ordre de l'app : un appui, aucun
 * mot de passe à inventer, et la boîte à lire en dernier. Rien ici ne touche à l'échange
 * lui-même : chaque page garde ses appels Supabase.
 */
export function ProviderButton({
  provider,
  label,
  pending,
  disabled = false,
  onPress,
  className = "",
}: {
  provider: "apple" | "google";
  label: string;
  pending: boolean;
  disabled?: boolean;
  onPress: () => void;
  className?: string;
}) {
  const apple = provider === "apple";
  return (
    <Button
      type="button"
      size="xl"
      variant="ghost"
      loading={pending}
      disabled={disabled}
      onClick={onPress}
      className={`h-12 w-full gap-2.5 rounded-[14px] text-[15.5px] font-bold sm:h-12 sm:text-[15.5px] ${
        apple
          ? "bg-ink text-on-ink hover:bg-ink/90 data-pressed:bg-ink/90 *:data-[slot=button-loading-indicator]:text-on-ink"
          : "bg-surface text-ink shadow-[inset_0_0_0_1.5px_var(--color-stroke-strong)] hover:bg-surface-muted"
      } ${className}`}
    >
      {apple ? <AppleIcon /> : <GoogleIcon />}
      {label}
    </Button>
  );
}

/** Le filet « ou » entre les fournisseurs et le courriel. */
export function OrDivider({ label }: { label: string }) {
  return (
    <div className="my-5 flex items-center gap-3" role="separator" aria-label={label}>
      <span className="h-px flex-1 bg-hairline" />
      <span className="text-[12.5px] font-bold uppercase tracking-caps text-ink-tertiary">{label}</span>
      <span className="h-px flex-1 bg-hairline" />
    </div>
  );
}

export function AppleIcon() {
  return (
    <svg aria-hidden viewBox="0 0 24 24" className="size-5 opacity-100" fill="currentColor">
      <path d="M16.5 12.6c0-2 1.6-3 1.7-3.1-.9-1.4-2.4-1.5-2.9-1.6-1.2-.1-2.4.7-3 .7-.6 0-1.6-.7-2.6-.7-1.3 0-2.6.8-3.3 2-1.4 2.4-.4 6 1 7.9.7.9 1.5 2 2.5 2 1 0 1.3-.6 2.5-.6s1.5.6 2.5.6 1.7-.9 2.4-1.9c.5-.7.7-1.1.9-1.6-2.3-.9-2.2-3.6-2.2-3.7zM14.6 5.9c.5-.6.9-1.5.8-2.4-.8 0-1.7.5-2.3 1.2-.5.6-.9 1.5-.8 2.3.9.1 1.8-.4 2.3-1.1z" />
    </svg>
  );
}

export function GoogleIcon() {
  return (
    <svg aria-hidden viewBox="0 0 24 24" className="size-5 opacity-100">
      <path fill="#4285F4" d="M23 12.2c0-.8-.1-1.6-.2-2.3H12v4.4h6.2a5.3 5.3 0 0 1-2.3 3.5v2.9h3.7c2.2-2 3.4-5 3.4-8.5z" />
      <path fill="#34A853" d="M12 23.5c3 0 5.5-1 7.3-2.7l-3.6-2.8a6.9 6.9 0 0 1-10.3-3.6H1.6v3A11.5 11.5 0 0 0 12 23.5z" />
      <path fill="#FBBC05" d="M5.4 14.4a6.9 6.9 0 0 1 0-4.4v-3H1.6a11.5 11.5 0 0 0 0 10.4z" />
      <path fill="#EA4335" d="M12 5.4c1.6 0 3.1.6 4.2 1.7l3.2-3.2A11.5 11.5 0 0 0 1.6 7l3.8 3a6.9 6.9 0 0 1 6.6-4.6z" />
    </svg>
  );
}
