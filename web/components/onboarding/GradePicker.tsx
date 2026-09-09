"use client";

import type { GradeChoice } from "@/lib/onboarding/grades";

/**
 * **Le choix d'une moyenne, dans le barème de son pays.**
 *
 * Des boutons et non un curseur. Un curseur demande de viser, puis de vérifier ce qu'on a
 * visé ; il est juste quand la valeur est continue et que l'exactitude n'importe pas. Une
 * moyenne n'est ni l'un ni l'autre : elle a douze valeurs possibles, elle se connaît par cœur,
 * et on veut la poser d'un geste. Douze boutons se lisent d'un regard et se touchent au doigt.
 *
 * Les libellés viennent tels quels du barème local, sans doublon : voir `lib/onboarding/grades`.
 */
export function GradePicker({
  choices,
  selected,
  onSelect,
  label,
}: {
  choices: GradeChoice[];
  selected?: number;
  onSelect: (score: number) => void;
  /** Ce que la grille demande, pour ceux qui l'écoutent. */
  label: string;
}) {
  return (
    <div role="group" aria-label={label} className="flex flex-wrap justify-center gap-2">
      {choices.map((choice) => {
        const on = choice.score === selected;
        return (
          <button
            key={choice.score}
            type="button"
            onClick={() => onSelect(choice.score)}
            aria-pressed={on}
            className={`numeral pressable flex h-12 min-w-[78px] items-center justify-center rounded-button px-3 text-[16px] font-semibold transition-colors duration-hover ${
              on
                ? "bg-accent text-on-ink"
                : "bg-surface-muted text-ink shadow-[inset_0_0_0_1px_var(--color-stroke-strong)] hover:bg-surface"
            }`}
          >
            {choice.label}
          </button>
        );
      })}
    </div>
  );
}
