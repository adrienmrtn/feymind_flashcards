"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { Lightbulb, X } from "lucide-react";

import { CARD_MASTERIES, CLOZE_GAP, SeededGenerator, cardMastery, masteryCounts, normalizeClozeGap, shuffled, studyQueue, type CardMastery, type LessonCard, type LessonTone } from "@micabo/core";

import { CardsRun, type LESSON_RATINGS, type RunCard } from "@/components/lesson/CardsRun";
import { KeywordText } from "@/components/lesson/KeywordText";
import { LessonPrimaryButton } from "@/components/lesson/LessonButtons";
import { gradeLessonCard } from "@/lib/actions/review";
import { useI18n } from "@/lib/i18n/client";
import { useLessonClock } from "@/lib/lesson/use-lesson-clock";
import { lessonPath } from "@/lib/lesson/routes";

export type HubCard = RunCard & LessonCard;

const MASTERY_COLORS: Record<CardMastery, string> = {
  new: "var(--color-accent)",
  learning: "var(--color-tone-yellow-vivid)",
  mastered: "var(--color-correct)",
};

/**
 * **Les flashcards d'une leçon** : « Ta progression » (nouvelles, en cours, maîtrisées),
 * « Commencer à réviser », puis toutes les cartes, chacune avec sa pastille. Jumeau de
 * `LessonCardsHub`.
 *
 * La révision prend d'abord les cartes dues, puis des nouvelles, quinze au plus par séance :
 * toutes les cartes de la leçon finissent par entrer dans le rythme, sans tout déverser d'un
 * coup. Les notes partent au serveur au fil de l'eau, sans attendre.
 */
export function CardsHub({ lessonId, tone, cards, autoStart = false }: { lessonId: string; tone: LessonTone; cards: HubCard[]; autoStart?: boolean }) {
  const { t } = useI18n();
  const [running, setRunning] = useState<HubCard[] | null>(null);
  const [shown, setShown] = useState(false);
  const clock = useLessonClock(lessonId, "flashcards");
  void clock;

  const queue = studyQueue(cards);
  const counts = masteryCounts(cards);
  const total = cards.length;

  const start = useCallback(() => {
    if (total === 0) return;
    setRunning(queue.length > 0 ? queue : shuffled(cards, new SeededGenerator(BigInt(Date.now()))).slice(0, 20));
  }, [cards, queue, total]);

  useEffect(() => {
    const timer = window.setTimeout(() => setShown(true), 150);
    return () => window.clearTimeout(timer);
  }, []);

  useEffect(() => {
    if (autoStart) start();
    // eslint-disable-next-line react-hooks/exhaustive-deps -- à l'ouverture seulement.
  }, [autoStart]);

  const grade = useCallback((card: RunCard, rating: (typeof LESSON_RATINGS)[number]) => {
    void gradeLessonCard({ cardId: card.id, rating, snapshot: card.snapshot });
  }, []);

  if (running) {
    return <CardsRun cards={running} tone={tone} onClose={() => setRunning(null)} onGrade={grade} />;
  }

  return (
    <div className="mx-auto flex w-full max-w-[560px] flex-col gap-[22px] pb-8">
      <div className="flex items-center justify-between">
        <Link href={lessonPath(lessonId)} aria-label={t("lesson.circle.close")} className="pressable flex size-10 items-center justify-center rounded-full text-ink hover:bg-surface-muted">
          <X aria-hidden="true" className="size-5" strokeWidth={2.6} />
        </Link>
      </div>
      <h1 className="text-[40px] font-extrabold leading-none tracking-tight-title text-ink">{t("lesson.nav.flashcards")}</h1>

      <section className="flex flex-col gap-[18px] rounded-[26px] bg-surface p-5 shadow-floating">
        <h2 className="text-[22px] font-extrabold text-ink">{t("lesson.cards.progress")}</h2>
        <div className="flex h-3.5 overflow-hidden rounded-pill bg-track">
          {CARD_MASTERIES.map((mastery) => (
            <span
              key={mastery}
              className="h-full transition-[width] duration-[900ms] ease-out"
              style={{ width: shown && total > 0 ? `${(counts[mastery] / total) * 100}%` : "0%", background: MASTERY_COLORS[mastery] }}
            />
          ))}
        </div>
        <ul className="flex flex-wrap justify-between gap-x-4 gap-y-1">
          {CARD_MASTERIES.map((mastery) => (
            <li key={mastery} className="flex items-center gap-1.5 text-[15px] font-semibold text-ink">
              <span aria-hidden="true" className="size-2.5 rounded-full" style={{ background: MASTERY_COLORS[mastery] }} />
              {counts[mastery]} {t(`lesson.cards.mastery.${mastery}`)}
            </li>
          ))}
        </ul>
        <LessonPrimaryButton onClick={start} disabled={total === 0}>
          <Lightbulb aria-hidden="true" className="size-5" strokeWidth={2.4} />
          {queue.length === 0 ? t("lesson.cards.reviewAnyway") : t("lesson.cards.start", { count: queue.length })}
        </LessonPrimaryButton>
        {total === 0 ? <p className="text-[15px] font-medium text-ink-secondary">{t("lesson.cards.empty")}</p> : null}
      </section>

      {total > 0 ? (
        <>
          <h2 className="pt-1.5 text-[24px] font-extrabold text-ink">{t("lesson.cards.all", { count: total })}</h2>
          <ul className="flex flex-col gap-3">
            {cards.map((card) => (
              <li key={card.id} className="flex items-center gap-3.5 rounded-[22px] bg-surface p-[18px] shadow-[inset_0_0_0_1.5px_var(--color-stroke)]">
                <div className="flex min-w-0 flex-1 flex-col gap-2">
                  <p className="line-clamp-2 text-[18px] font-extrabold leading-snug" style={{ color: `var(--color-tone-${tone}-ink)` }}>
                    <KeywordText text={card.kind === "cloze" ? normalizeClozeGap(card.front).replaceAll(CLOZE_GAP, "____") : card.front} tints={false} />
                  </p>
                  <p className="line-clamp-3 text-[16px] font-medium leading-snug text-ink-secondary">
                    <KeywordText text={card.kind === "choice" && card.choices[card.correctChoiceIndex] ? card.choices[card.correctChoiceIndex]! : card.back} tints={false} />
                  </p>
                </div>
                <span aria-label={t(`lesson.cards.mastery.${cardMastery(card)}`)} role="img" className="size-3.5 shrink-0 rounded-full" style={{ background: MASTERY_COLORS[cardMastery(card)] }} />
              </li>
            ))}
          </ul>
        </>
      ) : null}
    </div>
  );
}
