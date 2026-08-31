"use client";

import { useState, useTransition } from "react";

import { deleteAccount } from "@/lib/actions/profile";
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
  const [open, setOpen] = useState(false);
  const [typed, setTyped] = useState("");
  const [failure, setFailure] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  const ready = typed.trim().toLowerCase() === "supprimer";

  function confirm() {
    if (!ready || pending) return;
    setFailure(null);
    forgetLocalAccount();
    startTransition(async () => {
      const result = await deleteAccount();
      if (result.status !== "ok") {
        setFailure(result.message ?? "Le compte n'a pas pu être supprimé.");
        return;
      }
      window.location.href = "/";
    });
  }

  return (
    <section className="saas-card relative mt-4 px-7 py-7">
      <div>
        <p className="text-[15px] font-semibold text-ink">Supprimer le compte</p>
        <p className="mt-1.5 max-w-[48ch] text-[13.5px] leading-relaxed text-ink-secondary">
          Tes cours, tes cartes et ton historique seront effacés. La même adresse
          {email ? (
            <>
              {" "}
              (<span className="text-ink">{email}</span>)
            </>
          ) : null}{" "}
          pourra servir à un compte neuf, comme si tu commençais aujourd&apos;hui.
          L&apos;abonnement déjà encaissé se gère chez Apple ou Stripe.
        </p>

        {open ? (
          <div className="mt-4">
            <label htmlFor="delete-account-confirm" className="block text-[13px] text-ink-tertiary">
              Écris <span className="font-medium text-ink">supprimer</span> pour confirmer.
            </label>
            <input
              id="delete-account-confirm"
              value={typed}
              onChange={(event) => setTyped(event.target.value)}
              autoComplete="off"
              className="mt-2 h-11 w-full max-w-[280px] rounded-button bg-surface-muted px-3 text-[15px] text-ink outline-none"
            />
            <div className="mt-3 flex flex-wrap items-center gap-2">
              <button
                type="button"
                disabled={!ready || pending}
                onClick={confirm}
                className="pressable rounded-button bg-negative px-4 py-2.5 text-[14px] font-semibold text-white disabled:opacity-40"
              >
                {pending ? "Suppression…" : "Supprimer définitivement"}
              </button>
              <button
                type="button"
                disabled={pending}
                onClick={() => {
                  setOpen(false);
                  setTyped("");
                  setFailure(null);
                }}
                className="pressable rounded-button px-3 py-2.5 text-[14px] text-ink-secondary"
              >
                Annuler
              </button>
            </div>
            {failure ? (
              <p className="mt-3 text-[13px] text-negative" role="alert">
                {failure}
              </p>
            ) : null}
          </div>
        ) : (
          <button
            type="button"
            onClick={() => setOpen(true)}
            className="pressable mt-4 text-[13.5px] font-medium text-negative"
          >
            Supprimer mon compte
          </button>
        )}
      </div>
    </section>
  );
}
