"use client";

import { useState, useTransition } from "react";

import { VISIBILITIES, isVisibility, type CourseVisibility } from "@micabo/core";

import { setCourseVisibility } from "@/lib/actions/profile";

/**
 * Qui peut retrouver ce cours, changé depuis la fiche.
 *
 * Il en faut un ici, et pas seulement à l'import : c'est ce qui rend le défaut public acceptable.
 * On ne demande pas à quelqu'un d'ouvrir ses cours sans lui donner le moyen d'en refermer un — et
 * la décision se prend en lisant la fiche, quand on voit ce qu'on est en train de partager.
 *
 * L'affichage change **avant** la réponse du serveur : l'app ne fait jamais attendre quelqu'un qui
 * vient de décider de se refermer. En cas d'échec, on revient à la valeur d'avant et on le dit.
 */
export function VisibilityPicker({
  courseId,
  initial,
}: {
  courseId: string;
  initial: string;
}) {
  const start: CourseVisibility = isVisibility(initial) ? initial : "public";
  const [value, setValue] = useState<CourseVisibility>(start);
  const [failed, setFailed] = useState(false);
  const [, startTransition] = useTransition();

  function choose(next: CourseVisibility) {
    if (next === value) return;
    const previous = value;
    setValue(next);
    setFailed(false);

    startTransition(async () => {
      const result = await setCourseVisibility(courseId, next);
      if (result.status === "error") {
        setValue(previous);
        setFailed(true);
      }
    });
  }

  return (
    <div data-print="hide">
      <div className="flex flex-wrap items-center gap-2">
        {VISIBILITIES.map((item) => (
          <button
            key={item.value}
            type="button"
            onClick={() => choose(item.value)}
            aria-pressed={value === item.value}
            className={`pressable rounded-pill px-3.5 py-2 text-[13px] font-medium transition-colors duration-hover ${
              value === item.value
                ? "bg-accent-soft text-accent"
                : "bg-surface-muted text-ink-secondary"
            }`}
          >
            {item.title}
          </button>
        ))}
      </div>
      <p className={`mt-2 text-[12.5px] ${failed ? "text-negative" : "text-ink-tertiary"}`}>
        {failed
          ? "Le réglage n'a pas pu être enregistré."
          : VISIBILITIES.find((item) => item.value === value)?.detail}
      </p>
    </div>
  );
}
