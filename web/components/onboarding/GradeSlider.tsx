"use client";

import { useEffect } from "react";

import type { GradeChoice } from "@/lib/onboarding/grades";

/**
 * **Une moyenne se règle, elle ne se choisit pas dans une liste.**
 *
 * Douze boutons alignés demandaient de lire douze libellés pour en toucher un, alors que ces
 * douze valeurs sont une seule chose qui monte. Un curseur dit ça d'un trait : on voit tout de
 * suite où l'on est sur l'échelle, et déplacer le pouce d'un cran est plus rapide que viser un
 * bouton de soixante-dix pixels.
 *
 * C'est un `input[type=range]` habillé, et pas une invention à base de `pointerdown`. Le
 * clavier, le lecteur d'écran, le glisser au doigt, le clic sur le rail, la molette : tout ça
 * existe déjà dedans, et une reconstruction maison en perd toujours la moitié. Ce qui est à
 * nous est le dessin, dans `globals.css`, et le libellé lu à voix haute - sans quoi un
 * lecteur d'écran annoncerait « 4 sur 11 » à la place de « 14/20 ».
 *
 * Le curseur part sur une valeur, et **cette valeur est écrite dès l'arrivée**. Un curseur qui
 * montre 15/20 sans que 15/20 soit la réponse enregistrée est un piège : ce qu'on voit est ce
 * qui compte, sinon le bouton Continuer refuserait d'avancer sans dire pourquoi.
 */
export function GradeSlider({
  choices,
  selected,
  onSelect,
  label,
  /** La position de départ, en rang dans la liste. Le milieu, sauf avis contraire. */
  fallbackIndex,
}: {
  choices: GradeChoice[];
  selected?: number;
  onSelect: (score: number) => void;
  label: string;
  fallbackIndex?: number;
}) {
  const known = choices.findIndex((choice) => choice.score === selected);
  const start = Math.min(
    choices.length - 1,
    Math.max(0, fallbackIndex ?? Math.floor((choices.length - 1) / 2)),
  );
  const index = known >= 0 ? known : start;
  const current = choices[index];

  useEffect(() => {
    if (known < 0 && current) onSelect(current.score);
    // Une seule fois : ensuite, c'est le curseur qui décide.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [known < 0]);

  if (!current) return null;

  const ratio = choices.length > 1 ? index / (choices.length - 1) : 1;

  return (
    <div>
      <p className="numeral text-center text-[46px] font-bold leading-none tracking-display text-ink sm:text-[54px]">
        {current.label}
      </p>

      <div className="mt-6 px-1">
        <input
          type="range"
          className="grade-slider"
          min={0}
          max={choices.length - 1}
          step={1}
          value={index}
          onChange={(event) => {
            const next = choices[Number(event.target.value)];
            if (next) onSelect(next.score);
          }}
          aria-label={label}
          aria-valuetext={current.label}
          style={{ ["--fill" as string]: `${ratio * 100}%` }}
        />

        <div className="numeral mt-3 flex justify-between text-[12.5px] text-ink-tertiary">
          <span>{choices[0]!.label}</span>
          <span>{choices[choices.length - 1]!.label}</span>
        </div>
      </div>
    </div>
  );
}
