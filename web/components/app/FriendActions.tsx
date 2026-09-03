"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";

import { acceptFriend, removeFriend, requestFriend } from "@/lib/actions/social";
import type { SocialResult } from "@/lib/actions/social";
import { useI18n } from "@/lib/i18n/client";
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
  const { t } = useI18n();
  const router = useRouter();
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);

  function run(action: () => Promise<SocialResult>) {
    setError(null);
    start(async () => {
      const result = await action();
      if (result.status === "error") {
        setError(result.message ?? t("app.common.errorGeneric"));
        return;
      }
      router.refresh();
      onDone?.();
    });
  }

  const buttons =
    relation === "me" ? (
      <span className="text-[12.5px] text-ink-tertiary">{t("app.friends.you")}</span>
    ) : relation === "friends" ? (
      <button
        type="button"
        disabled={pending}
        onClick={() => run(() => removeFriend(personId))}
        className="pressable text-[12.5px] font-medium text-ink-tertiary"
      >
        {t("app.friends.remove")}
      </button>
    ) : relation === "requested" ? (
      <button
        type="button"
        disabled={pending}
        onClick={() => run(() => removeFriend(personId))}
        className="pressable text-[12.5px] font-medium text-ink-tertiary"
      >
        {t("app.common.cancel")}
      </button>
    ) : relation === "awaitingMe" ? (
      <span className="flex items-center gap-3">
        <button
          type="button"
          disabled={pending}
          onClick={() => run(() => acceptFriend(personId))}
          className="pressable text-[12.5px] font-semibold text-accent"
        >
          {t("app.friends.accept")}
        </button>
        <button
          type="button"
          disabled={pending}
          onClick={() => run(() => removeFriend(personId))}
          className="pressable text-[12.5px] font-medium text-ink-tertiary"
        >
          {t("app.friends.decline")}
        </button>
      </span>
    ) : (
      <button
        type="button"
        disabled={pending}
        onClick={() => run(() => requestFriend(personId))}
        className="pressable text-[12.5px] font-semibold text-accent"
      >
        {t("app.common.add")}
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
