import { MIKA_INNER, MIKA_VIEWBOX } from "./mika-art";
import type { MikaMood } from "./moods";

import "./mika.css";

/**
 * **Mika, la mascotte, dessinée et animée par le design.**
 *
 * Le dessin et le mouvement viennent de `design/mika/` tels quels : un SVG dont chaque partie
 * du corps est un calque, et une feuille de style qui, pour chaque humeur, dit ce qui bouge.
 * C'est leur format d'origine — l'iPhone les traduit en natif, le site les joue directement.
 * Changer d'humeur fond les yeux, la bouche et les effets en 0,18 s, comme le design.
 * « Réduire les animations » fige Mika dans la pose de son humeur (la feuille le sait).
 *
 * Sans `size`, Mika prend la largeur de son parent (`.mico` sans `.static`), ce qui est la
 * bonne façon de le poser dans une colonne ; avec, il mesure ce qu'on lui dit.
 */
export function Mika({
  mood = "idle",
  size,
  label = "Mika",
  className,
}: {
  mood?: MikaMood;
  size?: number;
  /** Ce que le lecteur d'écran dit. Vide : décoratif, Mika est à côté d'un texte qui parle. */
  label?: string;
  className?: string;
}) {
  const classes = ["mico", `s-${mood}`, size ? "static" : null, className].filter(Boolean).join(" ");
  return (
    <svg
      className={classes}
      viewBox={MIKA_VIEWBOX}
      width={size}
      height={size}
      role={label ? "img" : undefined}
      aria-label={label || undefined}
      aria-hidden={label ? undefined : true}
      xmlns="http://www.w3.org/2000/svg"
      dangerouslySetInnerHTML={{ __html: MIKA_INNER }}
    />
  );
}
