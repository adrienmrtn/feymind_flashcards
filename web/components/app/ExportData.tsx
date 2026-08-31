"use client";

import { useState, useTransition } from "react";

import { exportAccountData } from "@/lib/actions/profile";

/**
 * Télécharge une copie JSON des données du compte.
 *
 * Le fichier n'est pas stocké : il est assemblé à la demande et part dans le
 * navigateur. C'est le chemin annoncé par la politique de confidentialité.
 */
export function ExportData() {
  const [pending, startTransition] = useTransition();
  const [failure, setFailure] = useState<string | null>(null);

  function download() {
    setFailure(null);
    startTransition(async () => {
      const result = await exportAccountData();
      if (result.status !== "ok" || !result.payload) {
        setFailure(result.message ?? "L'export n'a pas pu être préparé.");
        return;
      }

      const blob = new Blob([JSON.stringify(result.payload, null, 2)], {
        type: "application/json",
      });
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = `micabo-donnees-${new Date().toISOString().slice(0, 10)}.json`;
      link.click();
      URL.revokeObjectURL(url);
    });
  }

  return (
    <section className="saas-card px-7 py-7">
      <p className="text-[15px] font-semibold text-ink">Télécharger mes données</p>
      <p className="mt-1.5 max-w-[48ch] text-[13.5px] leading-relaxed text-ink-secondary">
        Une copie de ton profil, tes cours, tes cartes, ton historique et tes examens.
        Le fichier n&apos;est pas gardé sur nos serveurs.
      </p>
      <button
        type="button"
        onClick={download}
        disabled={pending}
        className="pressable mt-4 rounded-button bg-ink px-4 py-2.5 text-[14px] font-semibold text-on-ink disabled:opacity-40"
      >
        {pending ? "Préparation…" : "Télécharger"}
      </button>
      {failure ? (
        <p className="mt-3 text-[13px] text-negative" role="alert">
          {failure}
        </p>
      ) : null}
    </section>
  );
}
