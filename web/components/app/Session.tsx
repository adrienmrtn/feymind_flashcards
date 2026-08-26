"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";

import {
  DETERMINISTIC_CONFIG,
  REVIEW_RATINGS,
  REVIEW_RATING_LABELS,
  ReviewRating,
  advanceSession,
  enqueueInitial,
  entitlement,
  formatDelay,
  previewLabels,
  returnsInSession,
  schedule,
  type CardSnapshot,
  type ScheduleOutcome,
  type SessionAdvance,
  type SessionEntry,
} from "@micabo/core";

import { InlineMarkup } from "@/components/sheet/InlineMarkup";
import { gradeCard } from "@/lib/actions/review";

/**
 * **La session, au clavier — et sans une seule animation.**
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
 * l'autre — c'est la fréquence qui décide, pas le goût.
 *
 * La file est celle d'Anki : une carte notée « 10 min » revient dans **cette** session. Finir le
 * paquet avant ces dix minutes n'est pas finir la journée. « Tout est à jour » n'apparaît que
 * lorsqu'il ne reste plus aucune carte due.
 *
 * L'écriture part au serveur **après** l'affichage de la carte suivante : le doigt n'attend pas le
 * réseau. Si une écriture échoue, on le dit sans défaire la session — la carte reviendra, ce qui
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
  snapshot: CardSnapshot;
}

interface Tally {
  answered: number;
  again: number;
  graduated: number;
}

type Loop = SessionAdvance<SessionCard>;

export function Session({ cards, isPro }: { cards: SessionCard[]; isPro: boolean }) {
  const [loop, setLoop] = useState<Loop>(() =>
    advanceSession(enqueueInitial(cards, new Date()), new Date()),
  );
  const [revealed, setRevealed] = useState(false);
  const [picked, setPicked] = useState<number | null>(null);
  const [tally, setTally] = useState<Tally>({ answered: 0, again: 0, graduated: 0 });
  const [failure, setFailure] = useState<string | null>(null);
  const [startedAt] = useState(() => Date.now());
  const [nowMs, setNowMs] = useState(() => Date.now());

  const card = loop.current;
  const remaining = (card ? 1 : 0) + loop.pending.length;

  // Le plafond du gratuit s'applique **à la session**, pas au jeu : les cartes restent toutes
  // visibles dans la liste du cours, et c'est le passage qui s'arrête. Le droit est lu par la
  // fonction du noyau, qui rend « ouvert » pour tout le monde tant que l'encaissement n'existe
  // pas — le chemin est donc écrit et ne se déclenche pas encore.
  const capped = entitlement.hasReachedSessionLimit({ isPro }, tally.answered);
  const finished = loop.done || capped;

  const labels = useMemo(() => (card ? previewLabels(card.snapshot) : null), [card]);

  const grade = useCallback(
    (rating: number) => {
      if (!card) return;
      const typed = rating as ReviewRating;
      const now = new Date();
      const outcome = schedule(card.snapshot, typed, { now, config: DETERMINISTIC_CONFIG });

      setTally((current) => ({
        ...current,
        answered: current.answered + 1,
        again: current.again + (typed === ReviewRating.again ? 1 : 0),
        graduated:
          current.graduated +
          (card.snapshot.state !== "review" && outcome.state === "review" ? 1 : 0),
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

  // Quand la prochaine carte n'est pas encore due, on reste dans la session et on
  // la sert à l'instant où son palier s'achève — pas avant, et surtout pas en
  // déclarant la journée finie.
  useEffect(() => {
    if (finished || !loop.nextAvailableAt) return;

    const delay = loop.nextAvailableAt.getTime() - Date.now();
    const timeout = window.setTimeout(() => {
      setLoop((current) => advanceSession(current.pending, new Date()));
    }, Math.max(0, delay));

    const tick = window.setInterval(() => setNowMs(Date.now()), 1000);

    return () => {
      window.clearTimeout(timeout);
      window.clearInterval(tick);
    };
  }, [finished, loop.nextAvailableAt]);

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
      <Completion
        tally={tally}
        minutes={elapsedMinutes(startedAt)}
        capped={capped}
        remaining={remaining}
      />
    );
  }

  if (!card) {
    const until = loop.nextAvailableAt;
    const seconds = until ? Math.max(0, (until.getTime() - nowMs) / 1000) : 0;

    return (
      <div className="mx-auto flex min-h-[calc(100svh-8rem)] max-w-[620px] flex-col">
        <div className="flex items-center gap-4">
          <div className="h-1 flex-1 overflow-hidden rounded-pill bg-progress-track">
            <div
              className="h-full rounded-pill bg-progress"
              style={{ width: `${progressWidth(tally.answered, remaining)}%` }}
            />
          </div>
          <p className="numeral shrink-0 text-[13px] font-semibold text-ink-tertiary">{remaining}</p>
        </div>

        <div className="flex flex-1 flex-col items-center justify-center py-16 text-center">
          <p className="text-[26px] font-bold text-ink">
            Prochaine carte dans {formatDelay(seconds)}
          </p>
          <p className="mt-3 max-w-[40ch] text-[15px] leading-relaxed text-ink-secondary">
            Elle revient dès que son palier est écoulé. Finir le paquet n&apos;est pas finir la
            journée.
          </p>
        </div>
      </div>
    );
  }

  if (!labels) return null;

  return (
    <div className="mx-auto flex min-h-[calc(100svh-8rem)] max-w-[620px] flex-col">
      <div className="flex items-center gap-4">
        <div className="h-1 flex-1 overflow-hidden rounded-pill bg-progress-track">
          <div
            className="h-full rounded-pill bg-progress"
            style={{ width: `${progressWidth(tally.answered, remaining)}%` }}
          />
        </div>
        <p className="numeral shrink-0 text-[13px] font-semibold text-ink-tertiary">{remaining}</p>
      </div>

      <div className="flex flex-1 flex-col justify-center py-8">
        <div className="paper rounded-group bg-surface p-7">
          {card.courseTitle ? (
            <p className="eyebrow text-ink-tertiary">{card.courseTitle}</p>
          ) : null}

          <p className="mt-3 text-[21px] font-semibold leading-snug text-ink">
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
                      className={`w-full rounded-button px-4 py-3 text-left text-[15px] ${tone}`}
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

      <div>
        {revealed ? (
          <div className="grid grid-cols-4 gap-2">
            {REVIEW_RATINGS.map((rating) => (
              <button
                key={rating}
                type="button"
                onClick={() => grade(rating)}
                className={`rounded-button px-2 py-3.5 text-center ${ratingTone(rating)}`}
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
            className="h-14 w-full rounded-button bg-ink text-[16px] font-semibold text-on-ink"
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

/** Le bilan : ce qui vient de se passer. La session s'arrête ici, et pas avant. */
function Completion({
  tally,
  minutes,
  capped,
  remaining,
}: {
  tally: Tally;
  minutes: number;
  capped: boolean;
  remaining: number;
}) {
  const accuracy =
    tally.answered > 0 ? Math.round(((tally.answered - tally.again) / tally.answered) * 100) : 100;

  return (
    <div className="mx-auto max-w-[520px] py-16 text-center">
      <p className="text-[28px] font-bold text-ink">
        {capped ? "C'est tout pour aujourd'hui." : "Tout est à jour."}
      </p>

      {capped ? (
        <p className="mx-auto mt-3 max-w-[40ch] text-[14.5px] leading-relaxed text-ink-secondary">
          Le gratuit sert {entitlement.FREE_TIER.cardsPerSession} cartes par session. Il t&apos;en
          reste <span className="numeral font-semibold text-ink">{remaining}</span> qui attendent.
        </p>
      ) : null}

      <dl className="mt-10 grid grid-cols-3 gap-4">
        <Stat value={tally.graduated} label="apprises" />
        <Stat value={`${accuracy} %`} label="de réussite" />
        <Stat value={minutes} label="min de révision" />
      </dl>

      <Link
        href="/app"
        className="pressable mt-12 inline-flex rounded-button bg-ink px-6 py-3.5 text-[15px] font-semibold text-on-ink"
      >
        Retour aux cours
      </Link>
    </div>
  );
}

function Stat({ value, label }: { value: string | number; label: string }) {
  return (
    <div className="paper rounded-group bg-surface py-5">
      <dd className="numeral text-[26px] font-bold text-ink">{value}</dd>
      <dt className="mt-1 text-[12px] text-ink-tertiary">{label}</dt>
    </div>
  );
}

/**
 * Les couleurs des quatre boutons.
 *
 * Ce sont celles des retours d'information de l'app, et elles disent « juste » et « faux » sans
 * qu'on plisse les yeux. Aucune transition dessus : c'est le geste le plus répété du produit.
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
  };
}

function progressWidth(answered: number, remaining: number): number {
  const total = answered + remaining;
  if (total <= 0) return 0;
  return (answered / total) * 100;
}
