"use client";

import type { Mastery } from "@micabo/core";

import { useI18n } from "@/lib/i18n/client";

import { Legend, TONE_VAR, type ChartTone } from "./primitives";

/**
 * La maîtrise, en une barre segmentée. **C'est la seule représentation de « ce que je sais »
 * dans le produit** : sur Progrès, sur une épreuve, sur un cours, c'est la même barre avec les
 * mêmes quatre couleurs, pour qu'on la lise d'un coup partout.
 *
 * Les segments sont séparés par deux pixels de blanc, pas par un trait : le vide sépare
 * mieux qu'une bordure et n'ajoute pas d'encre.
 */
export function MasteryBar({
  mastery,
  size = "md",
  legend = true,
  className = "",
}: {
  mastery: Mastery;
  size?: "sm" | "md";
  legend?: boolean;
  className?: string;
}) {
  const { t } = useI18n();
  const total = Math.max(1, mastery.cardCount);
  const parts: { key: ChartTone; value: number; label: string }[] = [
    { key: "solid", value: mastery.solid, label: t("app.home.mastery.solid") },
    { key: "fragile", value: mastery.fragile, label: t("app.home.mastery.fragile") },
    { key: "work", value: mastery.learning, label: t("app.home.mastery.learning") },
    { key: "untouched", value: mastery.untouched, label: t("app.home.mastery.untouched") },
  ];
  const drawn = parts.filter((part) => part.value > 0);

  return (
    <div className={className}>
      <div
        className={`flex w-full gap-[2px] overflow-hidden rounded-full ${size === "sm" ? "h-1.5" : "h-2.5"}`}
        role="img"
        aria-label={t("app.home.mastery.aria", {
          percent: mastery.percent,
          solid: mastery.solid,
          fragile: mastery.fragile,
          learning: mastery.learning,
          untouched: mastery.untouched,
        })}
      >
        {drawn.length === 0 ? (
          <span className="h-full w-full" style={{ backgroundColor: TONE_VAR.untouched }} />
        ) : (
          drawn.map((part) => (
            <span
              key={part.key}
              className="h-full rounded-[1px] first:rounded-l-full last:rounded-r-full"
              style={{ width: `${(part.value / total) * 100}%`, backgroundColor: TONE_VAR[part.key] }}
              title={`${part.label} · ${part.value}`}
            />
          ))
        )}
      </div>
      {legend ? (
        <Legend
          className="mt-3"
          items={parts.map((part) => ({ tone: part.key, label: part.label, value: part.value }))}
        />
      ) : null}
    </div>
  );
}
