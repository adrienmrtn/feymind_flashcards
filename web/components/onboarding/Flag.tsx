"use client";

import { useState } from "react";

/**
 * Un drapeau, **dessiné et non écrit.**
 *
 * L'emoji ne suffit pas, et ça a été vérifié deux fois : un drapeau Unicode est une paire de
 * lettres régionales, et une police qui n'a pas ces glyphes affiche « FR ». Forcer une pile de
 * polices à emoji marche sur les machines qui en ont une — pas sur les autres, et pas sur les
 * navigateurs qui refusent la substitution dans un bloc de texte.
 *
 * L'image, elle, ne dépend d'aucune police. L'emoji reste derrière en repli, pour le cas où le
 * réseau ne rend pas l'image : c'est toujours mieux qu'un carré vide.
 *
 * Le ratio 4:3 est celui de la source. La bordure très légère détache un drapeau à fond blanc —
 * la Suisse, la Pologne — du papier ivoire, sans quoi il n'a plus de contour.
 */
export function Flag({
  iso,
  emoji,
  label,
  className = "h-6 w-8",
}: {
  iso: string;
  emoji: string;
  label: string;
  className?: string;
}) {
  const [failed, setFailed] = useState(false);

  if (!iso || failed) {
    return (
      <span aria-hidden className="emoji text-[22px] leading-none">
        {emoji}
      </span>
    );
  }

  return (
    /* eslint-disable-next-line @next/next/no-img-element */
    <img
      src={`https://flagcdn.com/w80/${iso.toLowerCase()}.png`}
      srcSet={`https://flagcdn.com/w160/${iso.toLowerCase()}.png 2x`}
      alt={label}
      width={32}
      height={24}
      loading="lazy"
      decoding="async"
      onError={() => setFailed(true)}
      className={`shrink-0 rounded-[3px] object-cover ${className}`}
    />
  );
}
