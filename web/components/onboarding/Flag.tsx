"use client";

import { useState } from "react";

/**
 * Un drapeau, **dessiné et non écrit.**
 *
 * L'emoji ne suffit pas, et ça a été vérifié deux fois : un drapeau Unicode est une paire de
 * lettres régionales, et une police qui n'a pas ces glyphes affiche « FR ». Forcer une pile de
 * polices à emoji marche sur les machines qui en ont une - pas sur les autres, et pas sur les
 * navigateurs qui refusent la substitution dans un bloc de texte.
 *
 * L'image, elle, ne dépend d'aucune police. Flagcdn d'abord ; Twemoji si le réseau refuse
 * la première. L'emoji reste derrière en dernier repli.
 *
 * Le ratio 4:3 est celui de la source. La bordure très légère détache un drapeau à fond blanc  - 
 * la Suisse, la Pologne - du papier ivoire, sans quoi il n'a plus de contour.
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
  const [source, setSource] = useState<"cdn" | "twemoji" | "emoji">("cdn");

  if (!iso || source === "emoji") {
    return (
      <span aria-hidden className="emoji text-[22px] leading-none">
        {emoji}
      </span>
    );
  }

  const src =
    source === "cdn"
      ? `https://flagcdn.com/w80/${iso.toLowerCase()}.png`
      : twemojiFlag(iso);

  return (
    /* eslint-disable-next-line @next/next/no-img-element */
    <img
      src={src}
      srcSet={
        source === "cdn" ? `https://flagcdn.com/w160/${iso.toLowerCase()}.png 2x` : undefined
      }
      alt={label}
      width={32}
      height={24}
      loading="lazy"
      decoding="async"
      onError={() => setSource((current) => (current === "cdn" ? "twemoji" : "emoji"))}
      className={`shrink-0 rounded-[3px] object-cover ${className}`}
    />
  );
}

function twemojiFlag(iso: string): string {
  const letters = iso.trim().toUpperCase();
  const first = (0x1f1e6 + letters.charCodeAt(0) - 65).toString(16);
  const second = (0x1f1e6 + letters.charCodeAt(1) - 65).toString(16);
  return `https://cdn.jsdelivr.net/gh/jdecked/twemoji@15.1.0/assets/svg/${first}-${second}.svg`;
}
