"use client";

import { useEffect, useState, useTransition } from "react";

import { ExamMark, examDeadline, type ExamMarkInfo } from "@/components/app/ExamMark";
import { OcclusionEditor } from "@/components/app/OcclusionEditor";
import { OcclusionFigure } from "@/components/app/OcclusionFigure";
import { InlineMarkup } from "@/components/sheet/InlineMarkup";
import { createCard, deleteCard, updateCard } from "@/lib/actions/cards";
import type { CardRow } from "@/lib/data/courses";
import { useI18n } from "@/lib/i18n/client";
import { formatDelayLocalized, previewLabelsLocalized, type Translator } from "@/lib/i18n/copy";

/**
 * Les cartes d'un cours, **en grille et modifiables.**
 *
 * Plus une pile de rangées : chaque carte a son propre bloc, comme sur l'étagère.
 * On corrige toujours au clavier, dans une feuille par-dessus — les voisines restent
 * en vue, et on ferme d'une touche.
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
  const { t } = useI18n();
  const [editing, setEditing] = useState<string | null>(null);
  const [adding, setAdding] = useState(false);
  const [occluding, setOccluding] = useState(false);

  const selected = cards.find((card) => card.id === editing);

  return (
    <div>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-[13px] text-ink-tertiary">{t("app.workshop.hint")}</p>
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
            {t("app.workshop.maskDiagram")}
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
            {t("app.workshop.writeCard")}
          </button>
        </div>
      </div>

      {cards.length > 0 ? (
        <div className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {cards.map((card, index) => (
            <Tile
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

function Tile({
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
  const { t } = useI18n();
  const labels = previewLabelsLocalized(
    t,
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
      className="flex h-full min-h-[11.5rem] flex-col rounded-2xl border border-border bg-card p-5 text-left shadow-xs/5 transition-[scale] duration-press ease-out-strong active:scale-[0.96]"
    >
      <span className="flex items-start justify-between gap-3">
        <span className="numeral text-[12px] font-semibold text-ink-tertiary">{index + 1}</span>
        <span className={`text-[11px] font-medium ${stateTone(card.state)}`}>
          {stateLabel(t, card.state)}
        </span>
      </span>

      <span className="mt-3 line-clamp-4 text-[15px] font-medium leading-snug text-ink">
        <InlineMarkup text={occlusion ? card.back : card.front} />
      </span>

      {occlusion ? (
        <span className="mt-2 inline-flex w-fit rounded-pill bg-accent-soft px-2 py-0.5 text-[11px] font-medium text-accent">
          {t("app.cardKind.occlusion")}
        </span>
      ) : (
        <span className="mt-2 line-clamp-3 text-[14px] leading-snug text-ink-secondary">
          <InlineMarkup text={card.back} />
        </span>
      )}

      {choices.length > 0 ? (
        <span className="mt-2 text-[12.5px] text-ink-tertiary">
          {t("app.workshop.choiceCount", {
            count: choices.length,
            n: (card.correct_choice_index ?? 0) + 1,
          })}
        </span>
      ) : null}

      {exam ? (
        <span className="mt-2">
          <ExamMark name={exam.name} daysRemaining={exam.daysRemaining} />
        </span>
      ) : null}

      <span className="numeral mt-auto pt-4 text-[12px] text-ink-tertiary">
        {card.state === "new"
          ? labels[3]
          : formatDelayLocalized(t, (new Date(card.due_date).getTime() - Date.now()) / 1000)}
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
  const { t } = useI18n();
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

      if (result.status === "error") setFailure(result.message ?? t("app.common.errorGeneric"));
      else onDone();
    });
  }

  function remove() {
    if (!card) return;
    setFailure(null);
    startTransition(async () => {
      const result = await deleteCard(card.id, courseId);
      if (result.status === "error") setFailure(result.message ?? t("app.common.errorGeneric"));
      else onDone();
    });
  }

  return (
    <div className="fixed inset-0 z-40 flex items-end justify-center bg-ink/35 p-4 sm:items-center">
      <button type="button" className="absolute inset-0" aria-label={t("app.a11y.close")} onClick={onDone} />
      <div className="relative max-h-[92svh] w-full max-w-[520px] overflow-y-auto rounded-sheet bg-canvas p-6 shadow-floating">
        <div className="flex items-start justify-between gap-4">
          <div>
            <p className="eyebrow text-ink-tertiary">
              {card ? t("app.workshop.edit") : t("app.workshop.fresh")}
            </p>
            <h2 className="mt-1 text-[22px] font-bold text-ink">
              {card
                ? occlusion
                  ? t("app.workshop.fixDiagram")
                  : t("app.workshop.fixCard")
                : t("app.workshop.writeOne")}
            </h2>
          </div>
          <button
            type="button"
            onClick={onDone}
            className="pressable text-[18px] text-ink-tertiary"
            aria-label={t("app.a11y.close")}
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
              {t("app.workshop.question")}
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
          {occlusion ? t("app.workshop.zoneName") : t("app.workshop.answer")}
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
            <p className="eyebrow text-ink-tertiary">{t("app.workshop.choices")}</p>
            <div className="mt-1.5 space-y-1.5">
              {choices.map((choice, index) => (
                <div key={index} className="flex items-center gap-2">
                  <button
                    type="button"
                    aria-label={t("app.workshop.correctAria", { n: index + 1 })}
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
                    aria-label={t("app.workshop.removeChoiceAria", { n: index + 1 })}
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
                ? "bg-accent text-on-ink"
                : "cursor-not-allowed bg-surface-sunken text-ink-tertiary"
            }`}
          >
            {pending ? "…" : card ? t("app.common.save") : t("app.workshop.addCard")}
          </button>

          <button
            type="button"
            onClick={onDone}
            className="pressable rounded-button px-3 py-2.5 text-[14px] text-ink-secondary"
          >
            {t("app.common.cancel")}
          </button>

          {!occlusion && choices.length < 6 ? (
            <button
              type="button"
              onClick={() => setChoices([...choices, ""])}
              className="pressable rounded-button px-3 py-2.5 text-[13.5px] text-ink-secondary underline-draw"
            >
              {choices.length === 0 ? t("app.workshop.makeChoice") : t("app.workshop.addChoice")}
            </button>
          ) : null}

          {card ? (
            <button
              type="button"
              onClick={remove}
              disabled={pending}
              className="pressable ml-auto rounded-button px-3 py-2.5 text-[13.5px] text-negative"
            >
              {t("app.common.delete")}
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

function stateLabel(t: Translator, state: string): string {
  switch (state) {
    case "new":
      return t("app.workshop.state.new");
    case "learning":
      return t("app.workshop.state.learning");
    case "relearning":
      return t("app.workshop.state.relearning");
    default:
      return t("app.workshop.state.review");
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
