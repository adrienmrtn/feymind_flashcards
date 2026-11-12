import { MIKA_POSES, MIKA_VIEWBOX, type MikaPose } from "./mika-art";
import type { MikaMood } from "./moods";

import "./mika.css";

/**
 * **Mika, la mascotte : le personnage plat et vectoriel de l'app** (direction artistique V3.3).
 *
 * Le dessin vient de `design/mika-v3/mika.js`, le même que l'iPhone retrace en SwiftUI : une
 * pose par humeur (`mika-art.ts`, écrit par `scripts/sync-mika.mjs`). Son bleu suit le thème
 * (`--mika-body`). Il ne saute pas, ne se déplace pas : il change de pose.
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
  mood?: MikaMood | MikaPose;
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
      dangerouslySetInnerHTML={{ __html: MIKA_POSES[mood] ?? MIKA_POSES.idle }}
    />
  );
}
