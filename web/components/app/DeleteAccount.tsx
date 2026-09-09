"use client";

import { useState, useTransition } from "react";

import { ROW_FIELD, SettingsRow } from "@/components/app/settings/Rows";
import { deleteAccount } from "@/lib/actions/profile";
import { useI18n } from "@/lib/i18n/client";
import { forgetLocalAccount } from "@/lib/onboarding/persist";

/**
 * La suppression du compte, **en deux temps**.
 *
 * Un bouton seul trop bas dans la page se clique par accident. On demande donc
 * d'écrire « supprimer » : c'est assez pénible pour n'être fait qu'exprès, et
 * assez clair pour qu'on sache ce qu'on fait.
 *
 * L'appareil est oublié **avant** l'appel : sinon les réponses du parcours
 * resteraient ici, et le prochain compte avec la même adresse les reprendrait.
 */
export function DeleteAccount({ email }: { email: string }) {
  const { t } = useI18n();
  const [open, setOpen] = useState(false);
  const [typed, setTyped] = useState("");
  const [failure, setFailure] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  const confirmWord = t("app.settings.delete.confirmWord");
  const ready = typed.trim().toLowerCase() === confirmWord.toLowerCase();

  function confirm() {
    if (!ready || pending) return;
    setFailure(null);
    forgetLocalAccount();
    startTransition(async () => {
      const result = await deleteAccount();
      if (result.status !== "ok") {
        setFailure(result.message ?? t("app.settings.delete.error"));
        return;
      }
      window.location.href = "/";
    });
  }

  return (
    <SettingsRow
      label={t("app.settings.delete.title")}
      tone="danger"
      hint={
        <>
          {t("app.settings.delete.body")}
          {email ? (
            <>
              {" "}
              (<span className="text-ink">{email}</span>)
            </>
          ) : null}
        </>
      }
      control={
        open ? null : (
          <button
            type="button"
            onClick={() => setOpen(true)}
            className="pressable h-10 rounded-button bg-negative-soft px-4 text-[13.5px] font-semibold text-negative"
          >
            {t("app.settings.delete.open")}
          </button>
        )
      }
    >
      {open ? (
        <div className="rise rounded-group bg-negative-soft p-4">
          <label
            htmlFor="delete-account-confirm"
            className="block text-[13px] text-ink-secondary"
          >
            {t("app.settings.delete.confirmLabel")}
          </label>
          <input
            id="delete-account-confirm"
            value={typed}
            onChange={(event) => setTyped(event.target.value)}
            autoComplete="off"
            className={`${ROW_FIELD} mt-2 w-full max-w-[280px] bg-surface`}
          />
          <div className="mt-3 flex flex-wrap items-center gap-2">
            <button
              type="button"
              disabled={!ready || pending}
              onClick={confirm}
              className="pressable h-10 rounded-button bg-negative px-4 text-[13.5px] font-semibold text-white disabled:opacity-40"
            >
              {pending ? t("app.settings.delete.pending") : t("app.settings.delete.confirm")}
            </button>
            <button
              type="button"
              disabled={pending}
              onClick={() => {
                setOpen(false);
                setTyped("");
                setFailure(null);
              }}
              className="pressable h-10 rounded-button px-3 text-[13.5px] text-ink-secondary"
            >
              {t("app.common.cancel")}
            </button>
          </div>
          {failure ? (
            <p className="mt-3 text-[13px] text-negative" role="alert">
              {failure}
            </p>
          ) : null}
        </div>
      ) : null}
    </SettingsRow>
  );
}
