"use client";

import { useState, useTransition } from "react";

import { displayUsername, normalizeUsername, validateUsername } from "@micabo/core";

import { ROW_FIELD, SettingsRow } from "@/components/app/settings/Rows";
import { setUsername } from "@/lib/actions/social";
import { useI18n } from "@/lib/i18n/client";

/**
 * Le @, écrit seul dans `profiles.username`.
 *
 * CloudSync n'emporte pas ce champ avec le reste du profil : un iPhone en
 * retard n'écraserait pas le nom qu'on vient de changer ici.
 */
export function UsernameField({ initial }: { initial: string }) {
  const { t } = useI18n();
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
          : (result.message ?? t("app.settings.saved.error")),
      );
      if (result.status === "ok" && result.username) setValue(result.username);
    });
  }

  return (
    <SettingsRow
      label={t("app.settings.usernameLabel")}
      htmlFor="profile-username"
      hint={
        <span className={kind === "erreur" ? "text-negative" : undefined}>
          {pending
            ? "…"
            : (message ?? (preview ? displayUsername(preview) : t("app.settings.usernameHelp")))}
        </span>
      }
      control={
        <div className={`${ROW_FIELD} flex w-[15rem] max-w-full items-center`}>
          <span className="pr-0.5 text-[14px] font-semibold text-ink-tertiary">@</span>
          <input
            id="profile-username"
            value={value}
            onChange={(event) => setValue(event.target.value)}
            onBlur={save}
            spellCheck={false}
            autoCapitalize="none"
            autoCorrect="off"
            placeholder={t("app.settings.usernamePlaceholder")}
            className="h-full min-w-0 flex-1 bg-transparent text-[14px] text-ink outline-none placeholder:text-ink-tertiary"
          />
        </div>
      }
    />
  );
}
