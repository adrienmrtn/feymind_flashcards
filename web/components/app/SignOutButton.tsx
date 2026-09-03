"use client";

import { useTransition } from "react";

import { signOut } from "@/lib/actions/profile";
import { useI18n } from "@/lib/i18n/client";

/**
 * Quitter la session, sans toucher au compte.
 *
 * La suppression est plus bas, et elle demande d'écrire un mot. Se déconnecter, c'est
 * l'inverse : un appui, et c'est un autre appareil - le même compte, plus cette session.
 */
export function SignOutButton({ compact = false }: { compact?: boolean }) {
  const { t } = useI18n();
  const [pending, startTransition] = useTransition();

  function leave() {
    if (pending) return;
    startTransition(() => {
      void signOut();
    });
  }

  if (compact) {
    return (
      <button
        type="button"
        onClick={leave}
        disabled={pending}
        aria-label={t("app.auth.signOut")}
        title={t("app.auth.signOut")}
        className="pressable flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-ink-secondary"
      >
        <DoorIcon />
      </button>
    );
  }

  return (
    <button
      type="button"
      onClick={leave}
      disabled={pending}
      className="pressable hover-row w-full px-7 py-5 text-left"
    >
      <p className="text-[15px] font-semibold text-ink">
        {pending ? t("app.auth.signingOut") : t("app.auth.signOut")}
      </p>
      <p className="mt-1 text-[13px] leading-relaxed text-ink-tertiary">
        {t("app.auth.signOutHint")}
      </p>
    </button>
  );
}

function DoorIcon() {
  return (
    <svg aria-hidden viewBox="0 0 20 20" className="h-5 w-5">
      <path
        d="M8 4H5a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h3M12 13l4-3-4-3M16 10H8"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.7"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
