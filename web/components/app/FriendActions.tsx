"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";

import { acceptFriend, removeFriend, requestFriend } from "@/lib/actions/social";
import type { SocialResult } from "@/lib/actions/social";
import type { Relation } from "@/lib/social";

export function FriendActions({
  personId,
  relation,
  onDone,
}: {
  personId: string;
  relation: Relation;
  onDone?: () => void;
}) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);

  function run(action: () => Promise<SocialResult>) {
    setError(null);
    start(async () => {
      const result = await action();
      if (result.status === "error") {
        setError(result.message ?? "Ça n'a pas marché.");
        return;
      }
      router.refresh();
      onDone?.();
    });
  }

  const buttons =
    relation === "me" ? (
      <span className="text-[12.5px] text-ink-tertiary">Toi</span>
    ) : relation === "friends" ? (
      <button
        type="button"
        disabled={pending}
        onClick={() => run(() => removeFriend(personId))}
        className="pressable text-[12.5px] font-medium text-ink-tertiary"
      >
        Retirer
      </button>
    ) : relation === "requested" ? (
      <button
        type="button"
        disabled={pending}
        onClick={() => run(() => removeFriend(personId))}
        className="pressable text-[12.5px] font-medium text-ink-tertiary"
      >
        Annuler
      </button>
    ) : relation === "awaitingMe" ? (
      <span className="flex items-center gap-3">
        <button
          type="button"
          disabled={pending}
          onClick={() => run(() => acceptFriend(personId))}
          className="pressable text-[12.5px] font-semibold text-accent"
        >
          Accepter
        </button>
        <button
          type="button"
          disabled={pending}
          onClick={() => run(() => removeFriend(personId))}
          className="pressable text-[12.5px] font-medium text-ink-tertiary"
        >
          Refuser
        </button>
      </span>
    ) : (
      <button
        type="button"
        disabled={pending}
        onClick={() => run(() => requestFriend(personId))}
        className="pressable text-[12.5px] font-semibold text-accent"
      >
        Ajouter
      </button>
    );

  return (
    <span className="flex flex-col items-end gap-1">
      {buttons}
      {error ? (
        <span className="max-w-[16ch] text-right text-[11px] text-negative" role="alert">
          {error}
        </span>
      ) : null}
    </span>
  );
}
