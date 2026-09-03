"use client";

import { knowledgePie, type KnowledgeBucket, type KnowledgeLevel } from "@micabo/core";

import { useI18n } from "@/lib/i18n/client";

const CX = 50;
const CY = 50;
const OUTER = 42;
const INNER = 26;

const TONE: Record<KnowledgeLevel, string> = {
  new: "fill-ink-tertiary/45",
  learning: "fill-accent",
  review: "fill-caution",
  mastered: "fill-ink",
};

/**
 * Le niveau de connaissance, en camembert.
 *
 * Quatre parts, les mêmes que les barres d'avant : nouvelles, en cours,
 * en révision, maîtrisées. Le trou du milieu porte le total — c'est le
 * seul chiffre qu'on compare d'un regard, le détail est dans la légende.
 */
const BUCKET_KEY: Record<KnowledgeLevel, string> = {
  new: "app.profile.mastery.bucket.new",
  learning: "app.profile.mastery.bucket.learning",
  review: "app.profile.mastery.bucket.review",
  mastered: "app.profile.mastery.bucket.mastered",
};

export function KnowledgePie({ buckets }: { buckets: readonly KnowledgeBucket[] }) {
  const { t } = useI18n();
  const slices = knowledgePie(buckets).map((slice) => ({
    ...slice,
    label: t(BUCKET_KEY[slice.id]),
  }));
  const total = buckets.reduce((sum, bucket) => sum + bucket.count, 0);
  const drawn = slices.filter((slice) => slice.sweep > 0);

  return (
    <div className="mt-6 flex flex-col items-center gap-8 sm:flex-row sm:items-center sm:justify-center sm:gap-10">
      <div className="relative size-[184px] shrink-0">
        <svg
          viewBox="0 0 100 100"
          className="size-full"
          role="img"
          aria-label={slices
            .map((slice) => t("app.profile.mastery.sliceAria", { count: slice.count, label: slice.label }))
            .join(", ")}
        >
          {drawn.length === 0 ? (
            <circle cx={CX} cy={CY} r={OUTER} className="fill-surface-muted" />
          ) : drawn.length === 1 ? (
            <path d={fullRing()} className={TONE[drawn[0]!.id]} />
          ) : (
            drawn.map((slice) => (
              <path
                key={slice.id}
                d={donutSlice(slice.start, slice.sweep)}
                className={TONE[slice.id]}
              />
            ))
          )}
          <circle cx={CX} cy={CY} r={INNER - 0.4} className="fill-surface" />
        </svg>
        <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
          <p className="numeral text-[22px] font-bold leading-none text-ink">{total}</p>
          <p className="mt-1 text-[11px] text-ink-tertiary">
            {t("app.profile.mastery.centerLabel", { count: total })}
          </p>
        </div>
      </div>

      <ul className="w-full max-w-[220px] space-y-2.5">
        {slices.map((slice) => (
          <li key={slice.id} className="flex items-baseline gap-2.5">
            <span
              aria-hidden
              className={`mt-0.5 size-2.5 shrink-0 rounded-[2px] ${swatch(slice.id)}`}
            />
            <span className="min-w-0 flex-1 truncate text-[13.5px] text-ink">
              {slice.label}
            </span>
            <span className="numeral shrink-0 text-[13.5px] font-semibold text-ink">
              {slice.count}
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}

function swatch(level: KnowledgeLevel): string {
  switch (level) {
    case "new":
      return "bg-ink-tertiary/45";
    case "learning":
      return "bg-accent";
    case "review":
      return "bg-caution";
    default:
      return "bg-ink";
  }
}

function polar(radius: number, turn: number): [number, number] {
  const angle = turn * Math.PI * 2 - Math.PI / 2;
  return [CX + radius * Math.cos(angle), CY + radius * Math.sin(angle)];
}

function fullRing(): string {
  return [
    `M ${CX} ${CY - OUTER}`,
    `A ${OUTER} ${OUTER} 0 1 1 ${CX} ${CY + OUTER}`,
    `A ${OUTER} ${OUTER} 0 1 1 ${CX} ${CY - OUTER}`,
    `M ${CX} ${CY - INNER}`,
    `A ${INNER} ${INNER} 0 1 0 ${CX} ${CY + INNER}`,
    `A ${INNER} ${INNER} 0 1 0 ${CX} ${CY - INNER}`,
    "Z",
  ].join(" ");
}

function donutSlice(start: number, sweep: number): string {
  const end = start + sweep;
  const large = sweep > 0.5 ? 1 : 0;
  const [ox1, oy1] = polar(OUTER, start);
  const [ox2, oy2] = polar(OUTER, end);
  const [ix2, iy2] = polar(INNER, end);
  const [ix1, iy1] = polar(INNER, start);
  return [
    `M ${ox1} ${oy1}`,
    `A ${OUTER} ${OUTER} 0 ${large} 1 ${ox2} ${oy2}`,
    `L ${ix2} ${iy2}`,
    `A ${INNER} ${INNER} 0 ${large} 0 ${ix1} ${iy1}`,
    "Z",
  ].join(" ");
}
