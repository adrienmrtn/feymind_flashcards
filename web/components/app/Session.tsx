"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";

import {
  REVIEW_RATINGS,
  REVIEW_RATING_LABELS,
  ReviewRating,
  entitlement,
  previewLabels,
  type CardSnapshot,
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

export function Session({ cards }: { cards: SessionCard[] }) {
  const [index, setIndex] = useState(0);
  const [revealed, setRevealed] = useState(false);
  const [picked, setPicked] = useState<number | null>(null);
  const [tally, setTally] = useState<Tally>({ answered: 0, again: 0, graduated: 0 });
  const [failure, setFailure] = useState<string | null>(null);
  const [startedAt] = useState(() => Date.now());

  const card = cards[index];

  // Le plafond du gratuit s'applique **à la session**, pas au jeu : les cartes restent toutes
  // visibles dans la liste du cours, et c'est le passage qui s'arrête. Le droit est lu par la
  // fonction du noyau, qui rend « ouvert » pour tout le monde tant que l'encaissement n'existe
  // pas — le chemin est donc écrit et ne se déclenche pas encore.
  const capped = entitlement.hasReachedSessionLimit(entitlement.resolve(), tally.answered);
  const finished = index >= cards.length || capped;

  const labels = useMemo(
    () => (card ? previewLabels(card.snapshot) : null),
    [card],
  );

  const grade = useCallback(
    (rating: number) => {
      if (!card) return;

      setTally((current) => ({
        ...current,
        answered: current.answered + 1,
        again: current.again + (rating === ReviewRating.again ? 1 : 0),
      }));

      // On avance **d'abord**. L'écriture suit, et son échec se dit sans rien défaire.
      setIndex((current) => current + 1);
      setRevealed(false);
      setPicked(null);

      const wasLearning = card.snapshot.state !== "review";

      void gradeCard({ cardId: card.id, rating, snapshot: card.snapshot }).then((result) => {
        if (result.status === "error") {
          setFailure(result.message ?? "Une note n'a pas été écrite.");
          return;
        }

        // **« Apprises » compte les cartes qui sont passées en révision**, et c'est le serveur
        // qui le dit — pas la note qu'on vient de donner.
        //
        // La première version le déduisait du bouton : « Correct » sur une carte neuve comptait
        // pour une carte apprise. C'est faux, et le test de bout en bout l'a montré — huit notes
        // annonçaient six cartes apprises quand la base n'en avait fait passer que deux. Une
        // carte neuve notée « Correct » avance d'un palier d'apprentissage et revient dans dix
        // minutes ; seule la sortie du dernier palier, ou un « Facile », la fait passer en
        // révision. Annoncer six cartes acquises pour deux, c'est promettre un progrès qui n'a
        // pas eu lieu.
        if (wasLearning && result.state === "review") {
          setTally((current) => ({ ...current, graduated: current.graduated + 1 }));
        }
      });
    },
    [card],
  );

  // Le clavier, et **rien qui l'intercepte à moitié** : espace ne doit pas faire défiler la page,
  // et une touche pressée pendant qu'un champ a le focus appartient au champ.
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (finished) return;
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
  }, [finished, revealed, grade]);

  if (finished) {
    return (
      <Completion
        tally={tally}
        minutes={elapsedMinutes(startedAt)}
        capped={capped}
        remaining={cards.length - index}
      />
    );
  }
  if (!card || !labels) return null;

  const progress = cards.length > 0 ? index / cards.length : 0;

  return (
    <div className="mx-auto flex min-h-[calc(100svh-8rem)] max-w-[620px] flex-col">
      <div className="flex items-center gap-4">
        <div className="h-1 flex-1 overflow-hidden rounded-pill bg-progress-track">
          <div
            className="h-full rounded-pill bg-progress"
            style={{ width: `${progress * 100}%` }}
          />
        </div>
        <p className="numeral shrink-0 text-[13px] font-semibold text-ink-tertiary">
          {cards.length - index}
        </p>
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

/** Le bilan : ce qui vient de se passer, et quand la prochaine revient. */
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
        {capped ? "C'est tout pour aujourd'hui." : tally.again === 0 ? "Sans faute." : "Session terminée"}
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
