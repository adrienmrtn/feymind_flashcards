"use client";

import { useEffect, useState, useTransition } from "react";

import { formatDelay, previewLabels } from "@micabo/core";

import { ExamMark, examDeadline, type ExamMarkInfo } from "@/components/app/ExamMark";
import { OcclusionEditor } from "@/components/app/OcclusionEditor";
import { OcclusionFigure } from "@/components/app/OcclusionFigure";
import { InlineMarkup } from "@/components/sheet/InlineMarkup";
import { createCard, deleteCard, updateCard } from "@/lib/actions/cards";
import type { CardRow } from "@/lib/data/courses";

/**
 * Les cartes d'un cours, **en table et modifiables.**
 *
 * C'est l'écran où le web bat le téléphone sans discussion : on corrige vingt cartes à la suite au
 * clavier, on voit d'un coup d'œil ce qui est neuf et ce qui revient bientôt.
 *
 * **Une carte écrite par un modèle doit pouvoir être corrigée.** L'édition s'ouvre dans une
 * feuille par-dessus la liste - pas en dessous de la rangée, et pas en plein écran : on garde
 * les voisines en vue, et on ferme d'une touche.
 */
export function CardList({
  courseId,
  cards,
  exam,
}: {
  courseId: string;
  cards: CardRow[];
  exam?: ExamMarkInfo | null;
}) {
  const [editing, setEditing] = useState<string | null>(null);
  const [adding, setAdding] = useState(false);
  const [occluding, setOccluding] = useState(false);

  const selected = cards.find((card) => card.id === editing);

  return (
    <div>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-[13px] text-ink-tertiary">Clique une carte pour la corriger.</p>
        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            onClick={() => {
              setAdding(false);
              setEditing(null);
              setOccluding(true);
            }}
            className="pressable rounded-button bg-surface px-4 py-2.5 text-[14px] font-semibold text-ink paper"
          >
            🖼️ Masquer un schéma
          </button>
          <button
            type="button"
            onClick={() => {
              setOccluding(false);
              setEditing(null);
              setAdding(true);
            }}
            className="pressable rounded-button bg-surface px-4 py-2.5 text-[14px] font-semibold text-ink paper"
          >
            ✍️ Écrire une carte
          </button>
        </div>
      </div>

      {cards.length > 0 ? (
        <div className="paper mt-4 overflow-hidden rounded-group bg-surface">
          {cards.map((card, index) => (
            <Row
              key={card.id}
              card={card}
              index={index}
              exam={exam}
              onEdit={() => setEditing(card.id)}
            />
          ))}
        </div>
      ) : null}

      {adding || selected ? (
        <CardEditor
          courseId={courseId}
          card={selected}
          onDone={() => {
            setAdding(false);
            setEditing(null);
          }}
        />
      ) : null}

      {occluding ? (
        <OcclusionEditor courseId={courseId} onDone={() => setOccluding(false)} />
      ) : null}
    </div>
  );
}

function Row({
  card,
  index,
  exam,
  onEdit,
}: {
  card: CardRow;
  index: number;
  exam?: ExamMarkInfo | null;
  onEdit: () => void;
}) {
  const labels = previewLabels(
    {
      state: card.state,
      intervalDays: card.interval_days,
      easeFactor: card.ease_factor,
      repetitions: card.repetitions,
      lapses: card.lapses,
      stepIndex: card.step_index,
      dueDate: card.due_date,
    },
    { deadline: examDeadline(exam) },
  );
  const occlusion = isOcclusion(card);
  const choices = card.choices ?? [];

  return (
    <button
      type="button"
      onClick={onEdit}
      className={`hover-row flex w-full items-start gap-4 px-5 py-4 text-left ${
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
          <InlineMarkup text={occlusion ? card.back : card.front} />
        </span>
        {occlusion ? (
          <span className="mt-1.5 inline-flex rounded-pill bg-accent-soft px-2 py-0.5 text-[11px] font-medium text-accent">
            Schéma
          </span>
        ) : (
          <span className="mt-1 block text-[14px] leading-snug text-ink-secondary">
            <InlineMarkup text={card.back} />
          </span>
        )}
        {exam ? (
          <span className="mt-1.5 block">
            <ExamMark name={exam.name} daysRemaining={exam.daysRemaining} />
          </span>
        ) : null}
        {choices.length > 0 ? (
          <span className="mt-1.5 block text-[12.5px] text-ink-tertiary">
            {choices.length} propositions · bonne réponse n°
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

function CardEditor({
  courseId,
  card,
  onDone,
}: {
  courseId: string;
  card?: CardRow;
  onDone: () => void;
}) {
  const occlusion = card ? isOcclusion(card) : false;
  const [front, setFront] = useState(card?.front ?? "");
  const [back, setBack] = useState(card?.back ?? "");
  const [choices, setChoices] = useState<string[]>(card?.choices ?? []);
  const [correct, setCorrect] = useState(card?.correct_choice_index ?? 0);
  const [failure, setFailure] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  const complete = front.trim().length > 0 && back.trim().length > 0;

  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      if (event.key === "Escape") onDone();
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onDone]);

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
            choices: occlusion || choices.length === 0 ? undefined : choices,
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
    <div className="fixed inset-0 z-40 flex items-end justify-center bg-ink/35 p-4 sm:items-center">
      <button type="button" className="absolute inset-0" aria-label="Fermer" onClick={onDone} />
      <div className="relative max-h-[92svh] w-full max-w-[520px] overflow-y-auto rounded-sheet bg-canvas p-6 shadow-floating">
        <div className="flex items-start justify-between gap-4">
          <div>
            <p className="eyebrow text-ink-tertiary">{card ? "Modifier" : "Nouvelle"}</p>
            <h2 className="mt-1 text-[22px] font-bold text-ink">
              {card ? (occlusion ? "Corriger le schéma" : "Corriger la carte") : "Écrire une carte"}
            </h2>
          </div>
          <button
            type="button"
            onClick={onDone}
            className="pressable text-[18px] text-ink-tertiary"
            aria-label="Fermer"
          >
            ✕
          </button>
        </div>

        {occlusion && card?.image_path ? (
          <div className="mt-5">
            <OcclusionFigure
              image={card.image_path}
              mask={{
                x: card.mask_x,
                y: card.mask_y,
                width: card.mask_width,
                height: card.mask_height,
              }}
              revealed
            />
          </div>
        ) : null}

        {occlusion ? null : (
          <>
            <label className="eyebrow mt-5 block text-ink-tertiary" htmlFor={`front-${card?.id ?? "new"}`}>
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
          </>
        )}

        <label className="eyebrow mt-4 block text-ink-tertiary" htmlFor={`back-${card?.id ?? "new"}`}>
          {occlusion ? "Nom de la zone" : "Réponse"}
        </label>
        <textarea
          id={`back-${card?.id ?? "new"}`}
          value={back}
          onChange={(event) => setBack(event.target.value)}
          rows={2}
          autoFocus={occlusion}
          className="mt-1.5 w-full resize-y rounded-button bg-surface px-3.5 py-2.5 text-[15px] text-ink outline-none paper"
        />

        {!occlusion && choices.length > 0 ? (
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

        <div className="mt-5 flex flex-wrap items-center gap-2">
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

          {!occlusion && choices.length < 6 ? (
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
    </div>
  );
}

function isOcclusion(card: CardRow): boolean {
  return card.kind === "occlusion" && Boolean(card.image_path) && card.mask_width > 0 && card.mask_height > 0;
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
