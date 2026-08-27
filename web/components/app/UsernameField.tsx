"use client";

import { useState, useTransition } from "react";

import { displayUsername, normalizeUsername, validateUsername } from "@micabo/core";

import { setUsername } from "@/lib/actions/social";

/**
 * Le @, écrit seul dans `profiles.username`.
 *
 * CloudSync n'emporte pas ce champ avec le reste du profil : un iPhone en
 * retard n'écraserait pas le nom qu'on vient de changer ici.
 */
export function UsernameField({ initial }: { initial: string }) {
  const [value, setValue] = useState(initial);
  const [message, setMessage] = useState<string | null>(null);
  const [kind, setKind] = useState<"ok" | "erreur" | null>(null);
  const [pending, startTransition] = useTransition();

  const preview = normalizeUsername(value);

  function save() {
    const parsed = validateUsername(value);
    if (!parsed.ok && parsed.problem === "empty" && !value.trim()) return;

    startTransition(async () => {
      const result = await setUsername(value);
      setKind(result.status === "ok" ? "ok" : "erreur");
      setMessage(
        result.status === "ok"
          ? displayUsername(result.username ?? preview)
          : (result.message ?? "Non enregistré"),
      );
      if (result.status === "ok" && result.username) setValue(result.username);
    });
  }

  return (
    <div className="mt-7">
      <div className="flex items-baseline justify-between gap-3">
        <label htmlFor="profile-username" className="text-[13px] text-ink-tertiary">
          Ton @
        </label>
        <p className={`text-[12.5px] ${kind === "erreur" ? "text-negative" : "text-ink-tertiary"}`}>
          {pending ? "…" : message ?? (preview ? displayUsername(preview) : "")}
        </p>
      </div>
      <div className="mt-2 flex h-12 items-center rounded-button bg-surface-muted px-4">
        <span className="pr-1 text-[15px] font-semibold text-ink-tertiary">@</span>
        <input
          id="profile-username"
          value={value}
          onChange={(event) => setValue(event.target.value)}
          onBlur={save}
          spellCheck={false}
          autoCapitalize="none"
          autoCorrect="off"
          placeholder="ton-nom"
          className="h-full min-w-0 flex-1 bg-transparent text-[15px] text-ink outline-none placeholder:text-ink-tertiary"
        />
      </div>
      <p className="mt-2 text-[12.5px] leading-relaxed text-ink-tertiary">
        Un seul @ par compte, le même sur le téléphone et ici. C&apos;est comme ça qu&apos;on
        t&apos;ajoute en ami.
      </p>
    </div>
  );
}
