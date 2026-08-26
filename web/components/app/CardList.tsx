"use client";

import { useState, useTransition } from "react";

import { formatDelay, previewLabels } from "@micabo/core";

import { InlineMarkup } from "@/components/sheet/InlineMarkup";
import { createCard, deleteCard, updateCard } from "@/lib/actions/cards";
import type { CardRow } from "@/lib/data/courses";

/**
 * Les cartes d'un cours, **en table et modifiables.**
 *
 * C'est l'écran où le web bat le téléphone sans discussion : on corrige vingt cartes à la suite au
 * clavier, on voit d'un coup d'œil ce qui est neuf et ce qui revient bientôt. L'app les montre une
 * par une, ce qui est le bon choix sous le pouce et le mauvais devant un clavier.
 *
 * **Une carte écrite par un modèle doit pouvoir être corrigée**, et c'est ce qui manquait : une
 * carte fausse révisée vingt fois installe l'erreur au lieu du cours. L'édition se fait sur place —
 * pas dans une feuille par-dessus, parce qu'on corrige en regardant les voisines.
 */
export function CardList({ courseId, cards }: { courseId: string; cards: CardRow[] }) {
  const [editing, setEditing] = useState<string | null>(null);
  const [adding, setAdding] = useState(false);

  return (
    <div>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-[13px] text-ink-tertiary">
          Clique une carte pour la corriger.
        </p>
        <button
          type="button"
          onClick={() => setAdding((value) => !value)}
          className="pressable rounded-button bg-surface px-4 py-2.5 text-[14px] font-semibold text-ink paper"
        >
          {adding ? "Annuler" : "Écrire une carte"}
        </button>
      </div>

      {adding ? (
        <Editor
          key="nouvelle"
          courseId={courseId}
          onDone={() => setAdding(false)}
          className="mt-3"
        />
      ) : null}

      <div className="paper mt-4 overflow-hidden rounded-group bg-surface">
        {cards.map((card, index) =>
          editing === card.id ? (
            <Editor
              key={card.id}
              courseId={courseId}
              card={card}
              onDone={() => setEditing(null)}
              className={index > 0 ? "border-t border-hairline" : ""}
            />
          ) : (
            <Row
              key={card.id}
              card={card}
              index={index}
              onEdit={() => setEditing(card.id)}
            />
          ),
        )}
      </div>
    </div>
  );
}

function Row({
  card,
  index,
  onEdit,
}: {
  card: CardRow;
  index: number;
  onEdit: () => void;
}) {
  const labels = previewLabels({
    state: card.state,
    intervalDays: card.interval_days,
    easeFactor: card.ease_factor,
    repetitions: card.repetitions,
    lapses: card.lapses,
    stepIndex: card.step_index,
  });

  return (
    <button
      type="button"
      onClick={onEdit}
      className={`flex w-full items-start gap-4 px-5 py-4 text-left transition-colors duration-hover hover:bg-surface-muted/60 ${
        index > 0 ? "border-t border-hairline" : ""
      }`}
    >
      <span
        aria-hidden
        className="numeral mt-0.5 w-6 shrink-0 text-[12px] font-semibold text-ink-tertiary"
      >
        {index + 1}
      </span>

      <span className="min-w-0 flex-1">
        <span className="block text-[15px] font-medium leading-snug text-ink">
          <InlineMarkup text={card.front} />
        </span>
        <span className="mt-1 block text-[14px] leading-snug text-ink-secondary">
          <InlineMarkup text={card.back} />
        </span>
        {card.choices.length > 0 ? (
          <span className="mt-1.5 block text-[12.5px] text-ink-tertiary">
            {card.choices.length} propositions · bonne réponse n°
            {(card.correct_choice_index ?? 0) + 1}
          </span>
        ) : null}
      </span>

      <span className="shrink-0 text-right">
        <span className={`block text-[11px] font-medium ${stateTone(card.state)}`}>
          {stateLabel(card.state)}
        </span>
        <span className="numeral mt-0.5 block text-[12px] text-ink-tertiary">
          {card.state === "new"
            ? labels[3]
            : formatDelay((new Date(card.due_date).getTime() - Date.now()) / 1000)}
        </span>
      </span>
    </button>
  );
}

/**
 * L'édition d'une carte, ou l'écriture d'une neuve.
 *
 * Le même composant sert les deux : ce sont les mêmes champs, et deux formulaires côte à côte
 * finiraient par différer sur une validation.
 */
function Editor({
  courseId,
  card,
  onDone,
  className = "",
}: {
  courseId: string;
  card?: CardRow;
  onDone: () => void;
  className?: string;
}) {
  const [front, setFront] = useState(card?.front ?? "");
  const [back, setBack] = useState(card?.back ?? "");
  const [choices, setChoices] = useState<string[]>(card?.choices ?? []);
  const [correct, setCorrect] = useState(card?.correct_choice_index ?? 0);
  const [failure, setFailure] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  const complete = front.trim().length > 0 && back.trim().length > 0;

  function save() {
    setFailure(null);
    startTransition(async () => {
      const result = card
        ? await updateCard({
            cardId: card.id,
            courseId,
            front,
            back,
            hint: card.hint,
            choices: choices.length > 0 ? choices : undefined,
            correctChoiceIndex: correct,
          })
        : await createCard({
            courseId,
            front,
            back,
            choices: choices.length > 0 ? choices : undefined,
            correctChoiceIndex: correct,
          });

      if (result.status === "error") setFailure(result.message ?? "Ça n'a pas marché.");
      else onDone();
    });
  }

  function remove() {
    if (!card) return;
    setFailure(null);
    startTransition(async () => {
      const result = await deleteCard(card.id, courseId);
      if (result.status === "error") setFailure(result.message ?? "Ça n'a pas marché.");
      else onDone();
    });
  }

  return (
    <div className={`bg-surface-muted/40 px-5 py-4 ${className}`}>
      <label className="eyebrow block text-ink-tertiary" htmlFor={`front-${card?.id ?? "new"}`}>
        Question
      </label>
      <textarea
        id={`front-${card?.id ?? "new"}`}
        value={front}
        onChange={(event) => setFront(event.target.value)}
        rows={2}
        autoFocus
        className="mt-1.5 w-full resize-y rounded-button bg-surface px-3.5 py-2.5 text-[15px] text-ink outline-none paper"
      />

      <label className="eyebrow mt-4 block text-ink-tertiary" htmlFor={`back-${card?.id ?? "new"}`}>
        Réponse
      </label>
      <textarea
        id={`back-${card?.id ?? "new"}`}
        value={back}
        onChange={(event) => setBack(event.target.value)}
        rows={2}
        className="mt-1.5 w-full resize-y rounded-button bg-surface px-3.5 py-2.5 text-[15px] text-ink outline-none paper"
      />

      {choices.length > 0 ? (
        <div className="mt-4">
          <p className="eyebrow text-ink-tertiary">Propositions</p>
          <div className="mt-1.5 space-y-1.5">
            {choices.map((choice, index) => (
              <div key={index} className="flex items-center gap-2">
                <button
                  type="button"
                  aria-label={`Bonne réponse : proposition ${index + 1}`}
                  aria-pressed={correct === index}
                  onClick={() => setCorrect(index)}
                  className={`h-5 w-5 shrink-0 rounded-full border-2 ${
                    correct === index ? "border-accent bg-accent" : "border-stroke-strong"
                  }`}
                />
                <input
                  value={choice}
                  onChange={(event) => {
                    const next = [...choices];
                    next[index] = event.target.value;
                    setChoices(next);
                  }}
                  className="h-10 min-w-0 flex-1 rounded-button bg-surface px-3 text-[14px] text-ink outline-none paper"
                />
                <button
                  type="button"
                  aria-label={`Retirer la proposition ${index + 1}`}
                  onClick={() => setChoices(choices.filter((_, at) => at !== index))}
                  className="pressable px-1.5 text-[13px] text-ink-tertiary"
                >
                  ✕
                </button>
              </div>
            ))}
          </div>
        </div>
      ) : null}

      <div className="mt-4 flex flex-wrap items-center gap-2">
        <button
          type="button"
          disabled={!complete || pending}
          onClick={save}
          className={`pressable rounded-button px-4 py-2.5 text-[14px] font-semibold ${
            complete && !pending
              ? "bg-ink text-on-ink"
              : "cursor-not-allowed bg-surface-sunken text-ink-tertiary"
          }`}
        >
          {pending ? "…" : card ? "Enregistrer" : "Ajouter la carte"}
        </button>

        <button
          type="button"
          onClick={onDone}
          className="pressable rounded-button px-3 py-2.5 text-[14px] text-ink-secondary"
        >
          Annuler
        </button>

        {choices.length < 6 ? (
          <button
            type="button"
            onClick={() => setChoices([...choices, ""])}
            className="pressable rounded-button px-3 py-2.5 text-[13.5px] text-ink-secondary underline-draw"
          >
            {choices.length === 0 ? "En faire un QCM" : "Ajouter une proposition"}
          </button>
        ) : null}

        {card ? (
          <button
            type="button"
            onClick={remove}
            disabled={pending}
            className="pressable ml-auto rounded-button px-3 py-2.5 text-[13.5px] text-negative"
          >
            Supprimer
          </button>
        ) : null}
      </div>

      {failure ? (
        <p className="mt-3 text-[13px] text-negative" role="alert">
          {failure}
        </p>
      ) : null}
    </div>
  );
}

function stateLabel(state: string): string {
  switch (state) {
    case "new":
      return "Nouvelle";
    case "learning":
      return "Apprentissage";
    case "relearning":
      return "Réapprentissage";
    default:
      return "Révision";
  }
}

function stateTone(state: string): string {
  switch (state) {
    case "new":
      return "text-accent";
    case "learning":
    case "relearning":
      return "text-caution";
    default:
      return "text-ink-tertiary";
  }
}
