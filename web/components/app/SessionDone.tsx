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
  const counts = REVIEW_RATINGS.map((rating) => ({
    rating,
    count: tally.ratings.filter((item) => item === rating).length,
  }));
  const peak = Math.max(1, ...counts.map((item) => item.count));

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
        <h1 className="text-lg font-semibold tracking-tight text-foreground">Terminé</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {capped
            ? `Le gratuit s'arrête à ${entitlement.FREE_TIER.cardsPerSession}. ${remaining} en attente.`
            : leftoverNew > 0
              ? `${summary} · ${leftoverNew} neuve${leftoverNew > 1 ? "s" : ""} hors rythme`
              : summary}
        </p>
      </header>

      {tally.ratings.length > 0 ? (
        <div className="rounded-2xl border border-border bg-card px-4 py-4">
          <div className="flex h-28 items-end gap-2">
            {counts.map((item, index) => (
              <div key={item.rating} className="flex min-w-0 flex-1 flex-col items-center gap-2">
                <span className="numeral text-[12px] font-semibold text-foreground">{item.count}</span>
                <div className="flex h-20 w-full items-end">
                  <div
                    className={`w-full rounded-t-md ${RATING_BAR[item.rating]}`}
                    style={{
                      height: ready
                        ? `${Math.max(item.count > 0 ? 10 : 4, Math.round((item.count / peak) * 100))}%`
                        : "4%",
                      transition: `height 480ms var(--ease-out-strong) ${index * 60}ms`,
                    }}
                  />
                </div>
                <span className="text-[11px] text-muted-foreground">{REVIEW_RATING_LABELS[item.rating]}</span>
              </div>
            ))}
          </div>
        </div>
      ) : null}

      <div className="flex flex-wrap items-center gap-2">
        {leftoverNew > 0 && !capped ? (
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
          variant={leftoverNew > 0 && !capped ? "outline" : "default"}
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
