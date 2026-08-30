"use client";

import { useMemo, useState } from "react";

import {
  DETERMINISTIC_CONFIG,
  REVIEW_RATINGS,
  REVIEW_RATING_LABELS,
  ReviewRating,
  previewLabels,
} from "@micabo/core";

import { InlineMarkup } from "@/components/sheet/InlineMarkup";
import { STORY_CARDS } from "@/components/onboarding/onboarding-cards";

/**
 * **Une vraie session, en petit.**
 *
 * On lit le recto, on ouvre l'indice si on cale, on voit la réponse, puis on se
 * note de 1 à 4 — et les délais sous les boutons sont ceux que l'ordonnanceur
 * calcule, pas des étiquettes écrites à la main. Une démonstration qui montre
 * « 1 min » sans que ce soit vrai promet une app qui n'existe pas.
 *
 * Aucun pivot : la vraie session ne pivote pas non plus, et c'est elle qu'on
 * montre ici.
 */
export function FlashcardStory() {
  const [index, setIndex] = useState(0);
  const [revealed, setRevealed] = useState(false);
  const [picked, setPicked] = useState<number | null>(null);

  const card = STORY_CARDS[Math.min(index, STORY_CARDS.length - 1)]!;

  // La carte est neuve : ses délais sont donc ceux d'un premier passage, avec
  // les paliers d'apprentissage de l'app.
  const labels = useMemo(
    () =>
      previewLabels(
        {
          state: "new",
          intervalDays: 0,
          easeFactor: DETERMINISTIC_CONFIG.startingEase,
          repetitions: 0,
          lapses: 0,
          stepIndex: 0,
          dueDate: new Date(),
        },
        { config: DETERMINISTIC_CONFIG },
      ),
    [],
  );

  function next() {
    setRevealed(false);
    setPicked(null);
    setIndex((current) => (current + 1) % STORY_CARDS.length);
  }

  return (
    <div className="mx-auto w-full max-w-[420px]">
      <div className="paper flex min-h-[15rem] w-full flex-col rounded-group bg-surface p-4">
        <div className="flex items-center justify-between gap-3">
          <span className="rounded-pill bg-surface-muted px-2 py-0.5 text-[10px] font-bold uppercase tracking-caps text-ink-tertiary">
            {card.kindLabel}
          </span>
          <span className="numeral text-[11.5px] text-ink-tertiary">
            {index + 1} / {STORY_CARDS.length}
          </span>
        </div>

        <p className="mt-3 flex flex-1 items-center text-[16.5px] font-semibold leading-snug text-ink">
          <InlineMarkup text={card.front} />
        </p>

        {card.choices ? (
          <ul className="mt-3 space-y-1.5">
            {card.choices.map((choice, choiceIndex) => {
              const correct = choiceIndex === (card.answerIndex ?? 0);
              const chosen = picked === choiceIndex;
              const tone =
                revealed && correct
                  ? "bg-positive-soft font-medium text-positive"
                  : revealed && chosen
                    ? "bg-negative-soft text-negative"
                    : "bg-surface-muted text-ink";
              return (
                <li key={choice}>
                  <button
                    type="button"
                    disabled={revealed}
                    onClick={() => {
                      setPicked(choiceIndex);
                      setRevealed(true);
                    }}
                    className={`pressable w-full rounded-button px-3 py-2 text-left text-[13.5px] ${tone}`}
                  >
                    {choice}
                  </button>
                </li>
              );
            })}
          </ul>
        ) : null}

        {revealed ? (
          <div className="mt-3.5 border-t border-hairline pt-3.5">
            <p className="text-[15px] leading-relaxed text-ink-reading">
              <InlineMarkup text={card.back} />
            </p>
            {card.note ? (
              <p className="mt-1.5 text-[12.5px] leading-relaxed text-ink-tertiary">{card.note}</p>
            ) : null}
          </div>
        ) : card.hint ? (
          <details className="mt-3.5">
            <summary className="cursor-pointer text-[12.5px] text-ink-tertiary">Un indice</summary>
            <p className="mt-1.5 text-[13px] text-ink-secondary">{card.hint}</p>
          </details>
        ) : null}
      </div>

      <div className="mt-3">
        {revealed ? (
          <div className="grid grid-cols-4 gap-1.5">
            {REVIEW_RATINGS.map((rating) => (
              <button
                key={rating}
                type="button"
                onClick={next}
                className={`pressable rounded-button px-1 py-2.5 text-center shadow-[inset_0_0_0_1px_color-mix(in_srgb,currentColor_16%,transparent)] ${ratingTone(rating)}`}
              >
                <span className="block text-[12px] font-semibold leading-tight">
                  {REVIEW_RATING_LABELS[rating]}
                </span>
                <span className="numeral mt-0.5 block text-[11px] opacity-70">
                  {labels[rating]}
                </span>
              </button>
            ))}
          </div>
        ) : (
          <button
            type="button"
            onClick={() => setRevealed(true)}
            className="pressable inline-flex h-11 w-full items-center justify-center rounded-button bg-ink text-[14.5px] font-semibold text-on-ink"
          >
            Voir la réponse
          </button>
        )}

        <p className="mt-2.5 text-center text-[11.5px] text-ink-tertiary">
          {revealed ? "Tu te notes, Micabo choisit quand la carte revient." : "Essaie de répondre avant de retourner."}
        </p>
      </div>
    </div>
  );
}

/** Les couleurs des quatre boutons, celles de la vraie session. */
function ratingTone(rating: number): string {
  switch (rating) {
    case ReviewRating.again:
      return "bg-negative-soft text-negative";
    case ReviewRating.hard:
      return "bg-caution-soft text-caution";
    case ReviewRating.good:
      return "bg-positive-soft text-positive";
    default:
      return "bg-accent-soft text-accent";
  }
}
