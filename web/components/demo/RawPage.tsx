"use client";

import { localizedDemoCourse, localizedRawLines } from "./demo-course";
import { useI18n } from "@/lib/i18n/client";

/**
 * La page telle qu'on la dépose : dense, sans hiérarchie, pénible.
 *
 * Le texte est rendu en **vraies lignes** et non en traits gris. Un faux document en barres
 * grises ressemble à une maquette, et on ne croit pas une transformation dont on n'a pas vu le
 * point de départ. Le titre est à la même taille que le reste, noyé dans le corps du texte :
 * c'est exactement ce qui rend un polycopié impossible à réviser.
 */
export function RawPage({
  className,
  /**
   * Remplit la hauteur qu'on lui donne au lieu de faire la sienne.
   *
   * La section de transformation tient les deux états dans un seul rectangle, et c'est la fiche
   * qui le dimensionne - elle est la plus haute. La page brute doit donc s'étendre : les lignes
   * s'écartent au lieu de laisser un blanc en bas, ce qui la rend d'ailleurs **plus** crédible
   * comme polycopié qu'un bloc de cinq lignes serrées en haut d'un cadre.
   */
  fill = false,
}: {
  className?: string;
  fill?: boolean;
}) {
  const { t } = useI18n();
  const course = localizedDemoCourse(t);
  const lines = localizedRawLines(t);

  return (
    <div
      className={`flex flex-col overflow-hidden rounded-button border border-stroke bg-surface ${
        fill ? "h-full" : ""
      } ${className ?? ""}`}
    >
      <div className="flex shrink-0 items-center gap-2 bg-surface-muted px-3 py-2">
        <span className="rounded-[3px] bg-[#B5573C] px-1.5 py-0.5 text-[8px] font-bold tracking-[0.6px] text-on-ink">
          PDF
        </span>
        <span className="truncate text-[11px] font-medium text-ink-secondary">
          {course.fileName}
        </span>
      </div>

      <div
        className={`flex flex-1 flex-col p-4 ${fill ? "justify-between gap-2" : "gap-1.5"}`}
      >
        {lines.map((line, index) => (
          <p
            key={index}
            className={`text-[9.5px] leading-[1.55] text-[#55504A] ${
              index === 0 ? "font-semibold" : ""
            }`}
          >
            {line}
          </p>
        ))}
      </div>
    </div>
  );
}
