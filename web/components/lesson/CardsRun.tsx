"use client";

import { useCallback, useEffect, useState } from "react";

import { CLOZE_GAP, LESSON_RATINGS, ReviewRating, normalizeClozeGap, type CardSnapshot, type LessonTone } from "@micabo/core";

import { CircleTopBar } from "@/components/lesson/CircleTopBar";
import { KeywordText } from "@/components/lesson/KeywordText";
import { LessonPrimaryButton } from "@/components/lesson/LessonButtons";
import { Mika } from "@/components/mika/Mika";
import { useI18n } from "@/lib/i18n/client";

/** Une carte, telle que la série la retourne. */
export interface RunCard {
  id: string;
  front: string;
  back: string;
  kind: string;
  choices: string[];
  correctChoiceIndex: number;
  snapshot: CardSnapshot;
}

/** Les trois notes d'une leçon : Encore, Bien, Facile. « Difficile » n'est pas dans l'interface. */
export { LESSON_RATINGS };

/**
 * **Une série de flashcards** : on retourne, on note Encore / Bien / Facile, et l'écran de fin
 * « 10 / 10 ». Jumeau de `LessonCardsRun`. Au clavier : espace retourne, 1 · 2 · 3 notent.
 */
export function CardsRun({
  cards,
  tone,
  onClose,
  onDone,
  onGrade,
}: {
  cards: RunCard[];
  tone: LessonTone;
  onClose: () => void;
  onDone?: () => void;
  onGrade: (card: RunCard, rating: (typeof LESSON_RATINGS)[number]) => void;
}) {
  const { t } = useI18n();
  const [index, setIndex] = useState(0);
  const [flipped, setFlipped] = useState(false);
  const [finished, setFinished] = useState(false);
  const card = cards[index] ?? null;
  const total = cards.length;
  const endTitle = onDone ? t("lesson.circle.next") : t("lesson.quiz.finish");
  const leave = () => (onDone ? onDone() : onClose());

  const rate = useCallback(
    (rating: (typeof LESSON_RATINGS)[number]) => {
      if (!card || !flipped) return;
      onGrade(card, rating);
      if (index + 1 < total) {
        setIndex(index + 1);
        setFlipped(false);
      } else {
        setFinished(true);
      }
    },
    [card, flipped, index, onGrade, total],
  );

  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      if (finished || !card) return;
      const target = event.target as HTMLElement | null;
      if (target && (target.tagName === "INPUT" || target.tagName === "TEXTAREA")) return;
      if (event.code === "Space" || event.key === "Enter") {
        event.preventDefault();
        if (!flipped) setFlipped(true);
        else rate(ReviewRating.good);
        return;
      }
      if (!flipped) return;
      const digit = Number(event.key);
      if (digit >= 1 && digit <= 3) {
        event.preventDefault();
        rate(LESSON_RATINGS[digit - 1]!);
      }
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [card, finished, flipped, rate]);

  return (
    <div className="flex min-h-[calc(100svh-6rem)] flex-col">
      <CircleTopBar progress={total === 0 ? 0 : index / total} tone={tone} label={total === 0 || finished ? null : `${index + 1} / ${total}`} onClose={onClose} />

      {total === 0 ? (
        <EndState mood="sleep" title={t("lesson.cards.empty")} button={endTitle} onLeave={leave} />
      ) : finished ? (
        <EndState mood="happy" big={`${total} / ${total}`} tone={tone} title={t("lesson.cards.done")} button={endTitle} onLeave={leave} />
      ) : card ? (
        <>
          <div className="mx-auto flex w-full max-w-[560px] flex-1 flex-col justify-center px-1 py-3">
            <div key={card.id} className="flip-scene notes-page-in">
              <button
                type="button"
                className="flip-card block w-full text-start"
                data-flipped={flipped}
                onClick={() => setFlipped((value) => !value)}
                aria-label={t("lesson.cards.flip")}
              >
                <FlashcardFace card={card} flipped={false} tone={tone} />
                <div className="flip-face flip-face-back">
                  <FlashcardFace card={card} flipped tone={tone} />
                </div>
              </button>
            </div>
          </div>
          <div className="lesson-bottom-bar -mx-4 bg-canvas px-4 pb-[max(0.75rem,env(safe-area-inset-bottom))] pt-2 lg:-mx-10 lg:px-10" data-print="hide">
            <div className="mx-auto w-full max-w-[560px]">
              {flipped ? (
                <div className="grid grid-cols-3 gap-2.5" role="group">
                  <RatingButton label={t("lesson.cards.again")} shortcut={1} color="var(--color-wrong)" onClick={() => rate(ReviewRating.again)} />
                  <RatingButton label={t("lesson.cards.good")} shortcut={2} color={`var(--color-tone-${tone}-vivid)`} onClick={() => rate(ReviewRating.good)} />
                  <RatingButton label={t("lesson.cards.easy")} shortcut={3} color="var(--color-correct)" onClick={() => rate(ReviewRating.easy)} />
                </div>
              ) : (
                <LessonPrimaryButton onClick={() => setFlipped(true)}>
                  {t("lesson.cards.flip")}
                  <kbd className="rounded-[5px] bg-white/15 px-2 py-0.5 text-[11px] font-medium">{t("app.session.spaceKey")}</kbd>
                </LessonPrimaryButton>
              )}
            </div>
          </div>
        </>
      ) : null}
    </div>
  );
}

function RatingButton({ label, shortcut, color, onClick }: { label: string; shortcut: number; color: string; onClick: () => void }) {
  return (
    <button type="button" onClick={onClick} className="pressable flex items-center justify-center gap-2 rounded-[16px] py-4 text-[17px] font-extrabold text-on-ink" style={{ background: color }}>
      {label}
      <kbd className="rounded-[5px] bg-white/20 px-1.5 text-[10px] font-medium">{shortcut}</kbd>
    </button>
  );
}

function EndState({ mood, big, tone, title, button, onLeave }: { mood: "sleep" | "happy"; big?: string; tone?: LessonTone; title: string; button: string; onLeave: () => void }) {
  return (
    <div className="score-in flex flex-1 flex-col items-center justify-center gap-[18px] px-1 pb-4 text-center">
      <Mika mood={mood} size={mood === "happy" ? 170 : 150} label="" />
      {big ? (
        <p className="numeral text-[56px] font-extrabold leading-none" style={{ color: tone ? `var(--color-tone-${tone}-ink)` : undefined }}>
          {big}
        </p>
      ) : null}
      <p className="text-[20px] font-bold text-ink">{title}</p>
      <div className="mt-4 w-full max-w-[420px]">
        <LessonPrimaryButton onClick={onLeave}>{button}</LessonPrimaryButton>
      </div>
    </div>
  );
}

/** Une flashcard, recto puis verso. Une question de quiz ratée garde ses propositions ; le verso montre la bonne et l'explication. */
export function FlashcardFace({ card, flipped, tone }: { card: RunCard; flipped: boolean; tone: LessonTone }) {
  const { t } = useI18n();
  // Une carte à trou d'où qu'elle vienne : « … » de l'app et du serveur, « ____ » des
  // anciennes cartes du site. Sans trou lisible, elle se retourne comme une carte simple et
  // montre sa réponse — c'est ce que font l'iPhone et Android (`ClozeGap.isPresent`).
  const front = card.kind === "cloze" ? normalizeClozeGap(card.front) : card.front;
  const isCloze = card.kind === "cloze" && front.includes(CLOZE_GAP);
  const isChoice = card.kind === "choice" && card.choices.length > 1;
  const correct = isChoice ? card.choices[card.correctChoiceIndex] : null;
  return (
    <div
      className="flip-face flex min-h-[320px] w-full flex-col gap-4 rounded-[28px] bg-surface p-6 shadow-floating"
      style={{ boxShadow: flipped ? `inset 0 0 0 2px var(--color-tone-${tone}-vivid), var(--shadow-floating)` : `inset 0 0 0 2px var(--color-stroke), var(--shadow-floating)` }}
    >
      <p className="text-[12px] font-bold uppercase tracking-caps" style={{ color: `var(--color-tone-${tone}-ink)` }}>
        {flipped ? t("lesson.cards.answer") : t("lesson.cards.question")}
      </p>

      {isCloze ? (
        <p className="text-[24px] font-extrabold leading-snug text-ink">
          <KeywordText text={flipped ? front.replaceAll(CLOZE_GAP, `**${card.back}**`) : front.replaceAll(CLOZE_GAP, "_____")} />
        </p>
      ) : (
        <p className={flipped ? "text-[18px] font-extrabold leading-snug text-ink-secondary" : "text-[24px] font-extrabold leading-snug text-ink"}>
          <KeywordText text={card.front} />
        </p>
      )}

      {isChoice && !flipped ? (
        <ul className="flex flex-col gap-2">
          {card.choices.map((choice, index) => (
            <li key={index} className="text-[17px] font-medium text-ink">
              • <KeywordText text={choice} />
            </li>
          ))}
        </ul>
      ) : null}

      {flipped ? (
        <>
          {correct ? (
            <p className="text-[24px] font-extrabold leading-snug text-correct-ink">
              <KeywordText text={correct} tints={false} />
            </p>
          ) : null}
          {!isCloze && card.back ? (
            <p className={isChoice ? "text-[17px] font-medium leading-snug text-ink" : "text-[22px] font-bold leading-snug text-ink"}>
              <KeywordText text={card.back} />
            </p>
          ) : null}
        </>
      ) : null}
    </div>
  );
}
