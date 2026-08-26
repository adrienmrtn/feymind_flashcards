"use client";

import { useEffect, useRef, useState } from "react";
import { ThinkingOrb } from "thinking-orbs";

import type { SheetBlock } from "@micabo/core";

import { SheetBlocks } from "@/components/sheet/SheetBlocks";
import { InlineMarkup } from "@/components/sheet/InlineMarkup";
import { createCard } from "@/lib/actions/cards";
import { explainSelection, type Explanation } from "@/lib/actions/cards";

/**
 * La fiche, **et le passage qu'on ne comprend pas.**
 *
 * On sélectionne trois mots, un bouton apparaît sous la souris, et Micabo explique — ancré dans ce
 * cours-là, pas dans la culture générale du modèle. C'est la fonctionnalité que l'app a et que le
 * web n'avait pas, alors que la fonction `explain-selection` était déployée depuis le début.
 *
 * Et l'explication **propose sa carte** : c'est le moment où l'on sait exactement ce qu'on n'avait
 * pas compris, donc le meilleur moment pour en faire une question. La fonction la rend déjà ; il ne
 * restait qu'à l'enregistrer d'un appui.
 */
export function SheetReader({
  courseId,
  blocks,
  tint,
}: {
  courseId: string;
  blocks: SheetBlock[];
  tint: string;
}) {
  const container = useRef<HTMLDivElement>(null);
  const [selection, setSelection] = useState<string | null>(null);
  const [panel, setPanel] = useState<"repos" | "attente" | "reponse">("repos");
  const [explanation, setExplanation] = useState<Explanation | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);

  // La sélection est lue sur le document, pas sur un état de React : c'est le navigateur qui la
  // tient, et la recopier à chaque frappe de souris la ferait clignoter.
  useEffect(() => {
    function read() {
      const active = window.getSelection();
      const text = active?.toString().trim() ?? "";
      if (!active || text.length < 2) {
        setSelection(null);
        return;
      }
      // Seule une sélection **dans la fiche** compte : sélectionner le titre de la page ne demande
      // pas une explication de cours.
      const node = active.anchorNode;
      if (!node || !container.current?.contains(node)) {
        setSelection(null);
        return;
      }
      setSelection(text.slice(0, 1_200));
    }

    document.addEventListener("selectionchange", read);
    return () => document.removeEventListener("selectionchange", read);
  }, []);

  async function ask() {
    if (!selection) return;
    setPanel("attente");
    setFailure(null);
    setExplanation(null);
    setSaved(false);

    const result = await explainSelection({ selection, courseId });
    if (result.status === "error" || !result.explanation) {
      setPanel("repos");
      setFailure(result.message ?? "L'explication n'a pas pu être écrite.");
      return;
    }
    setExplanation(result.explanation);
    setPanel("reponse");
  }

  async function keepCard() {
    if (!explanation?.card) return;
    const result = await createCard({
      courseId,
      front: explanation.card.front,
      back: explanation.card.back,
    });
    if (result.status === "ok") setSaved(true);
  }

  return (
    <div>
      <div ref={container} className="max-w-reading">
        <SheetBlocks blocks={blocks} tint={tint} />
      </div>

      {/* La barre d'action de la sélection, ancrée en bas : un bouton flottant qui suit le curseur
          se place sous la souris et masque ce qu'on vient de sélectionner. */}
      {selection && panel === "repos" ? (
        <div
          className="rise fixed inset-x-0 bottom-6 z-30 mx-auto flex w-fit max-w-[92vw] items-center gap-3 rounded-pill bg-ink px-5 py-3 shadow-floating"
          data-print="hide"
        >
          <span className="max-w-[36ch] truncate text-[13px] text-on-ink-muted">
            « {selection} »
          </span>
          <button
            type="button"
            onClick={ask}
            className="pressable shrink-0 rounded-pill bg-on-ink px-4 py-1.5 text-[13.5px] font-semibold text-ink"
          >
            Explique-moi
          </button>
        </div>
      ) : null}

      {panel === "attente" ? (
        <div className="paper mt-8 flex items-center gap-4 rounded-group bg-surface p-5" data-print="hide">
          <ThinkingOrb state="composing" size={64} />
          <p className="text-[15.5px] font-semibold text-ink" role="status">
            Micabo relit ce passage…
          </p>
        </div>
      ) : null}

      {panel === "reponse" && explanation ? (
        <aside
          className="paper rise mt-8 max-w-reading rounded-group bg-surface p-6"
          data-print="hide"
        >
          <div className="flex items-start justify-between gap-4">
            <p className="eyebrow text-accent">Explication</p>
            <button
              type="button"
              onClick={() => {
                setPanel("repos");
                setExplanation(null);
              }}
              aria-label="Fermer l'explication"
              className="pressable -mr-1 -mt-1 text-[15px] text-ink-tertiary"
            >
              ✕
            </button>
          </div>

          <p className="mt-2.5 text-[17px] font-semibold leading-snug text-ink">
            <InlineMarkup text={explanation.headline} />
          </p>

          {explanation.body ? (
            <p className="mt-3 text-[15px] leading-relaxed text-ink-reading">
              <InlineMarkup text={explanation.body} />
            </p>
          ) : null}

          {explanation.example ? (
            <div className="mt-4 rounded-button bg-surface-muted px-4 py-3">
              <p className="eyebrow text-ink-tertiary">Exemple</p>
              <p className="mt-1.5 text-[14px] leading-relaxed text-ink-reading">
                <InlineMarkup text={explanation.example} />
              </p>
            </div>
          ) : null}

          {explanation.watchOut ? (
            <div className="mt-2.5 rounded-button bg-caution-soft px-4 py-3">
              <p className="eyebrow text-caution">Attention</p>
              <p className="mt-1.5 text-[14px] leading-relaxed text-ink-reading">
                <InlineMarkup text={explanation.watchOut} />
              </p>
            </div>
          ) : null}

          {explanation.card ? (
            <div className="mt-5 border-t border-hairline pt-5">
              <p className="text-[13px] text-ink-tertiary">
                Micabo propose d&apos;en faire une carte :
              </p>
              <p className="mt-2 text-[14.5px] font-medium text-ink">{explanation.card.front}</p>
              <p className="mt-1 text-[14px] text-ink-secondary">{explanation.card.back}</p>

              <button
                type="button"
                onClick={keepCard}
                disabled={saved}
                className={`pressable mt-3.5 rounded-button px-4 py-2.5 text-[14px] font-semibold ${
                  saved ? "bg-accent-soft text-accent" : "bg-ink text-on-ink"
                }`}
              >
                {saved ? "Carte ajoutée" : "Garder cette carte"}
              </button>
            </div>
          ) : null}
        </aside>
      ) : null}

      {failure ? (
        <p
          className="mt-6 max-w-reading rounded-button bg-negative-soft px-4 py-3 text-[13.5px] text-negative"
          role="alert"
          data-print="hide"
        >
          {failure}
        </p>
      ) : null}
    </div>
  );
}
