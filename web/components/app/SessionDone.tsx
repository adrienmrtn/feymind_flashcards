"use client";

import { useEffect, useState } from "react";
import Link from "next/link";

import {
  REVIEW_RATING_LABELS,
  REVIEW_RATINGS,
  ReviewRating,
  entitlement,
} from "@micabo/core";

/**
 * Le bilan d'une session : des graphes, des chiffres qui montent, des emojis.
 *
 * Pas un paragraphe de félicitations. On vient de noter des cartes : on relit
 * le geste — la courbe des notes, la part de chacune, ce que ça a produit.
 */

export interface SessionTally {
  answered: number;
  again: number;
  graduated: number;
  ratings: ReviewRating[];
}

const RATING_EMOJI: Record<ReviewRating, string> = {
  [ReviewRating.again]: "🔁",
  [ReviewRating.hard]: "😅",
  [ReviewRating.good]: "👍",
  [ReviewRating.easy]: "⚡",
};

const RATING_BAR: Record<ReviewRating, string> = {
  [ReviewRating.again]: "bg-negative",
  [ReviewRating.hard]: "bg-caution",
  [ReviewRating.good]: "bg-positive",
  [ReviewRating.easy]: "bg-accent",
};

const BURST = ["🎉", "✨", "📈", "🧠", "⚡", "🎯"];

export function SessionDone({
  tally,
  minutes,
  capped,
  remaining,
}: {
  tally: SessionTally;
  minutes: number;
  capped: boolean;
  remaining: number;
}) {
  const [ready, setReady] = useState(false);
  const accuracy =
    tally.answered > 0 ? Math.round(((tally.answered - tally.again) / tally.answered) * 100) : 100;
  const counts = REVIEW_RATINGS.map((rating) => ({
    rating,
    count: tally.ratings.filter((item) => item === rating).length,
  }));
  const peak = Math.max(1, ...counts.map((item) => item.count));

  useEffect(() => {
    const frame = requestAnimationFrame(() => setReady(true));
    return () => cancelAnimationFrame(frame);
  }, []);

  return (
    <div className="relative mx-auto max-w-[560px] overflow-hidden py-10 text-center">
      <div aria-hidden className="pointer-events-none absolute inset-x-0 top-0 h-28">
        {BURST.map((emoji, index) => (
          <span
            key={emoji}
            className="emoji-pop emoji absolute text-[22px]"
            style={{
              left: `${8 + index * 16}%`,
              top: index % 2 === 0 ? "8px" : "28px",
              animationDelay: `${80 + index * 70}ms`,
            }}
          >
            {emoji}
          </span>
        ))}
      </div>

      <p
        className="emoji-pop emoji mt-8 text-[42px]"
        aria-hidden
        style={{ animationDelay: "40ms" }}
      >
        {capped ? "⏸️" : "🎉"}
      </p>
      <h1 className="rise mt-3 text-[28px] font-bold text-ink" style={{ animationDelay: "80ms" }}>
        {capped ? "C'est tout pour aujourd'hui." : "Tout est à jour."}
      </h1>

      {capped ? (
        <p className="rise mx-auto mt-3 max-w-[40ch] text-[14.5px] leading-relaxed text-ink-secondary">
          Le gratuit sert {entitlement.FREE_TIER.cardsPerSession} cartes par session. Il t&apos;en
          reste <span className="numeral font-semibold text-ink">{remaining}</span> qui attendent.
        </p>
      ) : (
        <p
          className="rise mt-2 text-[14.5px] text-ink-secondary"
          style={{ animationDelay: "140ms" }}
        >
          {tally.answered === 0
            ? "Rien à revoir. Reviens demain."
            : `${tally.answered} carte${tally.answered > 1 ? "s" : ""} notée${tally.answered > 1 ? "s" : ""} · ${minutes} min`}
        </p>
      )}

      {tally.ratings.length > 0 ? (
        <>
          <section className="rise mt-10 text-left" style={{ animationDelay: "180ms" }}>
            <p className="eyebrow mb-3 text-ink-tertiary">📈 La session</p>
            <div className="paper flex h-28 items-end gap-1 rounded-group bg-surface px-4 pb-3 pt-4">
              {tally.ratings.map((rating, index) => (
                <div
                  key={`${rating}-${index}`}
                  className={`min-w-0 flex-1 rounded-t-md ${RATING_BAR[rating]}`}
                  title={REVIEW_RATING_LABELS[rating]}
                  style={{
                    height: ready ? `${(rating / ReviewRating.easy) * 100}%` : "0%",
                    transition: `height 520ms var(--ease-out-strong) ${index * 28}ms`,
                  }}
                />
              ))}
            </div>
            <p className="mt-2 text-center text-[12px] text-ink-tertiary">
              🔁 À revoir · 😅 Difficile · 👍 Correct · ⚡ Facile
            </p>
          </section>

          <section className="rise mt-8 text-left" style={{ animationDelay: "260ms" }}>
            <p className="eyebrow mb-3 text-ink-tertiary">🎯 Tes notes</p>
            <div className="paper rounded-group bg-surface px-5 py-5">
              <div className="flex h-36 items-end gap-3">
                {counts.map((item, index) => (
                  <div key={item.rating} className="flex min-w-0 flex-1 flex-col items-center gap-2">
                    <span className="numeral text-[13px] font-semibold text-ink">
                      {item.count}
                    </span>
                    <div className="flex h-24 w-full items-end">
                      <div
                        className={`w-full rounded-t-md ${RATING_BAR[item.rating]}`}
                        style={{
                          height: ready
                            ? `${Math.max(item.count > 0 ? 10 : 4, Math.round((item.count / peak) * 100))}%`
                            : "4%",
                          transition: `height 560ms var(--ease-out-strong) ${120 + index * 80}ms`,
                        }}
                      />
                    </div>
                    <span className="emoji text-[16px]" aria-hidden>
                      {RATING_EMOJI[item.rating]}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          </section>
        </>
      ) : null}

      <dl className="rise mt-8 grid grid-cols-3 gap-3" style={{ animationDelay: "340ms" }}>
        <Tile emoji="🌱" value={tally.graduated} label="apprises" />
        <Tile emoji="🎯" value={`${accuracy} %`} label="de réussite" />
        <Tile emoji="⏱️" value={minutes} label="min" />
      </dl>

      <Link
        href="/app"
        className="pressable shiny rise mt-10 inline-flex rounded-button bg-ink px-6 py-3.5 text-[15px] font-semibold text-on-ink"
        style={{ animationDelay: "420ms" }}
      >
        🏠 Retour aux cours
      </Link>
    </div>
  );
}

function Tile({ emoji, value, label }: { emoji: string; value: string | number; label: string }) {
  return (
    <div className="paper rounded-group bg-surface py-5">
      <p className="text-[18px]" aria-hidden>
        {emoji}
      </p>
      <dd className="numeral mt-1 text-[26px] font-bold text-ink">{value}</dd>
      <dt className="mt-1 text-[12px] text-ink-tertiary">{label}</dt>
    </div>
  );
}
