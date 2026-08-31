"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";

import {
  REVIEW_RATING_LABELS,
  REVIEW_RATINGS,
  ReviewRating,
  entitlement,
} from "@micabo/core";

import { Button } from "@/components/ui/button";
import { requestPaywall } from "@/lib/paywall";
import { heldBackNew } from "@/lib/micabo-copy";

export interface SessionTally {
  answered: number;
  again: number;
  graduated: number;
  ratings: ReviewRating[];
}

const RATING_BAR: Record<ReviewRating, string> = {
  [ReviewRating.again]: "bg-negative",
  [ReviewRating.hard]: "bg-caution",
  [ReviewRating.good]: "bg-positive",
  [ReviewRating.easy]: "bg-accent",
};

export function SessionDone({
  tally,
  minutes,
  capped,
  remaining,
  leftoverNew = 0,
}: {
  tally: SessionTally;
  minutes: number;
  capped: boolean;
  remaining: number;
  leftoverNew?: number;
}) {
  const router = useRouter();
  const [ready, setReady] = useState(false);
  const accuracy =
    tally.answered > 0 ? Math.round(((tally.answered - tally.again) / tally.answered) * 100) : 100;
  const given = REVIEW_RATINGS.map((rating) => ({
    rating,
    count: tally.ratings.filter((item) => item === rating).length,
  })).filter((item) => item.count > 0);

  useEffect(() => {
    const frame = requestAnimationFrame(() => setReady(true));
    return () => cancelAnimationFrame(frame);
  }, []);

  const summary =
    tally.answered === 0
      ? "Rien de noté."
      : `${tally.answered} carte${tally.answered > 1 ? "s" : ""} · ${minutes} min · ${accuracy} %`;

  return (
    <div className="space-y-5">
      <header>
        <h1 className="text-lg font-semibold tracking-tight text-foreground">C&apos;est fait</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {capped
            ? `Le gratuit s'arrête à ${entitlement.FREE_TIER.cardsPerSession}. ${remaining} en attente.`
            : leftoverNew > 0
              ? `${summary} · ${heldBackNew(leftoverNew)}`
              : summary}
        </p>
      </header>

      {given.length > 0 ? (
        // Des colonnes pleines largeur, surtout à zéro, faisaient un graphe plat
        // et trop large. Une note jamais donnée n'a pas de ligne.
        <div className="max-w-md rounded-2xl border border-border bg-card px-4 py-4">
          <ul className="space-y-3">
            {given.map((item, index) => {
              const share = item.count / Math.max(tally.answered, 1);
              return (
                <li
                  key={item.rating}
                  aria-label={`${REVIEW_RATING_LABELS[item.rating]} : ${item.count} sur ${tally.answered}`}
                >
                  <div className="flex items-baseline justify-between gap-3">
                    <span className="text-[13px] font-medium text-foreground">
                      {REVIEW_RATING_LABELS[item.rating]}
                    </span>
                    <span className="numeral text-[13px] font-semibold text-foreground">
                      {item.count}
                    </span>
                  </div>
                  <div className="mt-1.5 h-1.5 overflow-hidden rounded-pill bg-progress-track">
                    <div
                      className={`h-full rounded-pill ${RATING_BAR[item.rating]}`}
                      style={{
                        width: ready ? `${Math.max(8, Math.round(share * 100))}%` : "0%",
                        transition: `width 480ms var(--ease-out-strong) ${index * 60}ms`,
                      }}
                    />
                  </div>
                </li>
              );
            })}
          </ul>
        </div>
      ) : null}

      <div className="flex flex-wrap items-center gap-2">
        {capped ? (
          <Button onClick={requestPaywall}>Continuer avec Pro</Button>
        ) : leftoverNew > 0 ? (
          <Button
            onClick={() => {
              router.push("/app/reviser");
              router.refresh();
            }}
          >
            Réviser encore
          </Button>
        ) : null}
        <Button
          variant={capped || leftoverNew > 0 ? "outline" : "default"}
          onClick={() => {
            router.push("/app");
            router.refresh();
          }}
        >
          Accueil
        </Button>
      </div>
    </div>
  );
}
