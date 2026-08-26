"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { ThinkingOrb } from "thinking-orbs";

import { generateCards } from "@/lib/actions/course";

/**
 * Demander des cartes, et choisir leur forme.
 *
 * Le quota par format est passé explicitement plutôt que laissé au modèle : sans lui, il rend
 * quatorze cartes recto verso et croit avoir bien fait. Trois formats servent trois choses — une
 * définition se demande à l'endroit, un choix qui se piège demande un QCM, une formulation exacte
 * demande un texte à trou.
 */
export function GenerateCards({ courseId, existing }: { courseId: string; existing: number }) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [failure, setFailure] = useState<string | null>(null);

  function ask() {
    setFailure(null);
    startTransition(async () => {
      const result = await generateCards(courseId);
      if (result.status === "error") setFailure(result.message ?? "Ça n'a pas marché.");
      else router.refresh();
    });
  }

  return (
    <div>
      <button
        type="button"
        onClick={ask}
        disabled={pending}
        className={`pressable flex items-center gap-3 rounded-button px-5 py-3.5 text-[15px] font-semibold ${
          pending ? "bg-surface-sunken text-ink-tertiary" : "bg-ink text-on-ink"
        }`}
      >
        {pending ? (
          <>
            <ThinkingOrb state="composing" size={20} />
            Micabo écrit les cartes…
          </>
        ) : existing === 0 ? (
          "Créer des cartes"
        ) : (
          "En ajouter"
        )}
      </button>

      {existing === 0 && !pending ? (
        <p className="mt-2.5 text-[13px] text-ink-tertiary">
          Recto verso, QCM et textes à trou — une quinzaine, tirées de la fiche.
        </p>
      ) : null}

      {failure ? (
        <p
          className="mt-4 rounded-button bg-negative-soft px-4 py-3 text-[13.5px] text-negative"
          role="alert"
        >
          {failure}
        </p>
      ) : null}
    </div>
  );
}
