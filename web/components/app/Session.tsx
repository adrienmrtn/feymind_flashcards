"use client";

import { useCallback, useEffect, useMemo, useState } from "react";

import {
  DETERMINISTIC_CONFIG,
  REVIEW_RATINGS,
  REVIEW_RATING_LABELS,
  ReviewRating,
  advanceSession,
  enqueueInitial,
  entitlement,
  previewLabels,
  returnsInSession,
  schedule,
  clampedToDeadline,
  type CardSnapshot,
  type ScheduleOutcome,
  type SessionAdvance,
  type SessionEntry,
} from "@micabo/core";

import { ExamMark, examDeadline, type ExamMarkInfo } from "@/components/app/ExamMark";
import { OcclusionFigure } from "@/components/app/OcclusionFigure";
import { SessionDone } from "@/components/app/SessionDone";
import { InlineMarkup } from "@/components/sheet/InlineMarkup";
import { gradeCard } from "@/lib/actions/review";

/**
 * **La session, au clavier - et sans une seule animation.**
 *
 * C'est la décision la plus contre-intuitive du site, et la mieux fondée. Espace retourne la carte,
 * 1 à 4 la notent, et ces deux gestes se font des centaines de fois par soirée de révision. Au-delà
 * de cent fois par jour, la règle n'est pas « animer discrètement », c'est **ne pas animer** : une
 * carte qui pivote joliment devient au bout de vingt cartes la chose qui ralentit le travail, et
 * une transition sur une action déclenchée au clavier se ressent comme un décalage entre la touche
 * et l'écran.
 *
 * Les mêmes cartes se retournent au survol sur la page d'accueil et dans la démonstration du
 * parcours, où elles se voient une fois. C'est la même animation, juste à un endroit et fausse à
 * l'autre - c'est la fréquence qui décide, pas le goût.
 *
 * La file est celle d'Anki SM-2 : une carte notée « 1 min », « 6 min » ou « 10 min »
 * revient dans **cette** session, et sans compte à rebours - quand il ne reste qu'elle,
 * on la sert tout de suite.
 * « Tout est à jour » n'apparaît que lorsque la file est vide.
 *
 * L'écriture part au serveur **après** l'affichage de la carte suivante : le doigt n'attend pas le
 * réseau. Si une écriture échoue, on le dit sans défaire la session - la carte reviendra, ce qui
 * est exactement ce que fait une carte mal notée.
 */

export interface SessionCard {
  id: string;
  front: string;
  back: string;
  hint: string | null;
  kind: string;
  choices: string[];
  answerIndex: number;
  courseTitle: string | null;
  exam: ExamMarkInfo | null;
  imagePath: string | null;
  maskX: number;
  maskY: number;
  maskWidth: number;
  maskHeight: number;
  snapshot: CardSnapshot;
}

interface Tally {
  answered: number;
  again: number;
  graduated: number;
  ratings: ReviewRating[];
}

type Loop = SessionAdvance<SessionCard>;

export function Session({
  cards,
  isPro,
  leftoverNew = 0,
}: {
  cards: SessionCard[];
  isPro: boolean;
  leftoverNew?: number;
}) {
  const [loop, setLoop] = useState<Loop>(() =>
    advanceSession(enqueueInitial(cards, new Date()), new Date()),
  );
  const [revealed, setRevealed] = useState(false);
  const [picked, setPicked] = useState<number | null>(null);
  const [tally, setTally] = useState<Tally>({ answered: 0, again: 0, graduated: 0, ratings: [] });
  const [failure, setFailure] = useState<string | null>(null);
  const [startedAt] = useState(() => Date.now());

  const card = loop.current;
  const remaining = (card ? 1 : 0) + loop.pending.length;

  // Le plafond du gratuit s'applique **à la session**, pas au jeu : les cartes restent toutes
  // visibles dans la liste du cours, et c'est le passage qui s'arrête. Le droit est lu par la
  // fonction du noyau, qui rend « ouvert » pour tout le monde tant que l'encaissement n'existe
  // pas - le chemin est donc écrit et ne se déclenche pas encore.
  const capped = entitlement.hasReachedSessionLimit({ isPro }, tally.answered);
  const finished = loop.done || capped;

  const labels = useMemo(
    () => (card ? previewLabels(card.snapshot, { deadline: examDeadline(card.exam) }) : null),
    [card],
  );

  const grade = useCallback(
    (rating: number) => {
      if (!card) return;
      const typed = rating as ReviewRating;
      const now = new Date();
      const outcome = clampedToDeadline(
        schedule(card.snapshot, typed, {
          now,
          config: DETERMINISTIC_CONFIG,
          dueDate: card.snapshot.dueDate,
        }),
        examDeadline(card.exam),
        now,
      );

      setTally((current) => ({
        ...current,
        answered: current.answered + 1,
        again: current.again + (typed === ReviewRating.again ? 1 : 0),
        graduated:
          current.graduated +
          (card.snapshot.state !== "review" && outcome.state === "review" ? 1 : 0),
        ratings: [...current.ratings, typed],
      }));

      const updated: SessionCard = { ...card, snapshot: snapshotFrom(outcome) };
      const nextPending: SessionEntry<SessionCard>[] = returnsInSession(outcome.dueDate, now)
        ? [...loop.pending, { card: updated, availableAt: outcome.dueDate }]
        : loop.pending;

      setLoop(advanceSession(nextPending, now));
      setRevealed(false);
      setPicked(null);

      void gradeCard({ cardId: card.id, rating: typed, snapshot: card.snapshot }).then((result) => {
        if (result.status === "error") {
          setFailure(result.message ?? "Une note n'a pas été écrite.");
        }
      });
    },
    [card, loop.pending],
  );

  // Le clavier, et **rien qui l'intercepte à moitié** : espace ne doit pas faire défiler la page,
  // et une touche pressée pendant qu'un champ a le focus appartient au champ.
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (finished || !card) return;
      const target = event.target as HTMLElement | null;
      if (target && (target.tagName === "INPUT" || target.tagName === "TEXTAREA")) return;

      if (event.code === "Space" || event.key === "Enter") {
        event.preventDefault();
        if (!revealed) setRevealed(true);
        else grade(ReviewRating.good);
        return;
      }

      if (!revealed) return;

      const digit = Number(event.key);
      if (digit >= 1 && digit <= 4) {
        event.preventDefault();
        grade(digit);
      }
    };

    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [finished, revealed, grade, card]);

  if (finished) {
    return (
      <SessionDone
        tally={tally}
        minutes={elapsedMinutes(startedAt)}
        capped={capped}
        remaining={remaining}
        leftoverNew={leftoverNew}
      />
    );
  }

  if (!card || !labels) return null;

  return (
    <div className="mx-auto flex min-h-[calc(100svh-8rem)] w-full max-w-page flex-col">
      <div className="flex items-center gap-4">
        <div className="h-1 flex-1 overflow-hidden rounded-pill bg-progress-track">
          <div
            className="h-full rounded-pill bg-progress"
            style={{ width: `${progressWidth(tally.answered, remaining)}%` }}
          />
        </div>
        <p className="numeral shrink-0 text-[13px] font-semibold text-ink-tertiary">{remaining}</p>
      </div>

      <div className="flex flex-1 flex-col items-center justify-center py-8">
        <div className="paper flex min-h-[min(22rem,58svh)] w-full max-w-[26rem] flex-col rounded-[22px] bg-card p-6 sm:p-7">
          {card.courseTitle || card.exam ? (
            <div className="flex items-start justify-between gap-3">
              {card.courseTitle ? (
                <p className="eyebrow min-w-0 truncate text-ink-tertiary">{card.courseTitle}</p>
              ) : (
                <span />
              )}
              {card.exam ? <ExamMark name={card.exam.name} daysRemaining={card.exam.daysRemaining} /> : null}
            </div>
          ) : null}

          {isOcclusion(card) ? (
            <div className="mt-3">
              <OcclusionFigure
                image={card.imagePath!}
                mask={{
                  x: card.maskX,
                  y: card.maskY,
                  width: card.maskWidth,
                  height: card.maskHeight,
                }}
                revealed={revealed}
              />
            </div>
          ) : null}

          <p className="mt-3 flex flex-1 items-center text-[21px] font-semibold leading-snug text-ink">
            <InlineMarkup text={card.front} />
          </p>

          {card.kind === "choice" && card.choices.length > 0 ? (
            <ul className="mt-5 space-y-2">
              {card.choices.map((choice, choiceIndex) => {
                const correct = choiceIndex === card.answerIndex;
                const chosen = picked === choiceIndex;
                const tone =
                  revealed && correct
                    ? "bg-positive-soft text-positive font-medium"
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
                      className={`pressable hover-row w-full rounded-button px-4 py-3 text-left text-[15px] ${tone}`}
                    >
                      {choice}
                    </button>
                  </li>
                );
              })}
            </ul>
          ) : null}

          {revealed ? (
            <div className="mt-6 border-t border-hairline pt-6">
              <p className="text-[17px] leading-relaxed text-ink-reading">
                <InlineMarkup text={card.back} />
              </p>
            </div>
          ) : (
            <>
              {/* L'indice n'apparaît que s'il existe : un indice tiré de la forme de la réponse
                  n'apprend rien et fait perdre confiance dans les vrais. */}
              {card.hint ? (
                <details className="mt-5">
                  <summary className="cursor-pointer text-[13.5px] text-ink-tertiary">
                    Un indice
                  </summary>
                  <p className="mt-2 text-[14px] text-ink-secondary">
                    <InlineMarkup text={card.hint} />
                  </p>
                </details>
              ) : null}
            </>
          )}
        </div>

        {failure ? (
          <p className="mt-4 text-[13px] text-negative" role="alert">
            {failure}
          </p>
        ) : null}
      </div>

      <div className="mx-auto w-full max-w-[26rem]">
        {revealed ? (
          <div className="grid grid-cols-4 gap-2">
            {REVIEW_RATINGS.map((rating) => (
              <button
                key={rating}
                type="button"
                onClick={() => grade(rating)}
                className={`pressable rounded-button px-2 py-3.5 text-center shadow-[inset_0_0_0_1px_color-mix(in_srgb,currentColor_16%,transparent)] ${ratingTone(rating)}`}
              >
                <span className="block text-[14px] font-semibold">
                  {REVIEW_RATING_LABELS[rating]}
                </span>
                <span className="numeral mt-0.5 block text-[12px] opacity-70">
                  {labels[rating]}
                </span>
                <kbd className="mt-1.5 inline-block rounded-[5px] bg-black/8 px-1.5 text-[10px] font-medium">
                  {rating}
                </kbd>
              </button>
            ))}
          </div>
        ) : (
          <button
            type="button"
            onClick={() => setRevealed(true)}
            className="inline-flex h-10 w-full items-center justify-center rounded-lg border border-primary bg-primary text-sm font-medium text-primary-foreground"
          >
            Voir la réponse
            <kbd className="ml-2.5 rounded-[5px] bg-white/15 px-2 py-0.5 text-[11px] font-medium">
              espace
            </kbd>
          </button>
        )}

        <p className="mt-3.5 text-center text-[12px] text-ink-tertiary">
          Espace retourne la carte, 1 à 4 la notent.
        </p>
      </div>
    </div>
  );
}

/**
 * Les couleurs des quatre boutons.
 *
 * Ce sont celles des retours d'information de l'app, et elles disent « juste » et « faux » sans
 * qu'on plisse les yeux. Le survol est le même geste que partout ailleurs : la tuile se soulève.
 */
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

function elapsedMinutes(startedAt: number): number {
  return Math.max(1, Math.round((Date.now() - startedAt) / 60_000));
}

function snapshotFrom(outcome: ScheduleOutcome): CardSnapshot {
  return {
    state: outcome.state,
    intervalDays: outcome.intervalDays,
    easeFactor: outcome.easeFactor,
    repetitions: outcome.repetitions,
    lapses: outcome.lapses,
    stepIndex: outcome.stepIndex,
    dueDate: outcome.dueDate,
  };
}

function progressWidth(answered: number, remaining: number): number {
  const total = answered + remaining;
  if (total <= 0) return 0;
  return (answered / total) * 100;
}

function isOcclusion(card: SessionCard): boolean {
  return (
    card.kind === "occlusion" &&
    Boolean(card.imagePath) &&
    card.maskWidth > 0 &&
    card.maskHeight > 0
  );
}
