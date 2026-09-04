import type { Route } from "next";
import Link from "next/link";

/**
 * Le stylo, coins arrondis. C'est le même fichier que le favicon.
 *
 * Le PNG est déjà masqué. On recoupe encore d'un filet en CSS : le halo
 * gris du squircle ne doit plus se lire à côté du mot « Micabo ».
 */
export function BrandMark({
  size = 32,
  className = "",
}: {
  size?: number;
  className?: string;
}) {
  return (
    <img
      src="/icon.png"
      alt=""
      width={size}
      height={size}
      className={`brand-mark shrink-0 ${className}`.trim()}
      draggable={false}
    />
  );
}

/**
 * Icône + mot, pour une barre ou un pied. Le lien porte le nom : l'image
 * reste muette (`alt=""`), elle ne ferait que répéter « Micabo ».
 */
export function BrandLockup({
  href,
  size = 28,
  word = "Micabo",
  className = "",
  wordClassName = "text-[15px] font-bold tracking-tight",
}: {
  href: Route;
  size?: number;
  word?: string;
  className?: string;
  wordClassName?: string;
}) {
  return (
    <Link href={href} className={`inline-flex items-center gap-2.5 ${className}`.trim()}>
      <BrandMark size={size} />
      <span className={wordClassName}>{word}</span>
    </Link>
  );
}

/**
 * Le monogramme posé en grand : icône, mot, et la ligne « étudier ».
 * Pour un écran d'accueil, pas pour une barre.
 */
export function BrandWordmark({
  mark = 88,
  className = "",
  tagline,
}: {
  mark?: number;
  className?: string;
  tagline: string;
}) {
  return (
    <div className={`flex flex-col items-center ${className}`.trim()}>
      <BrandMark size={mark} />
      <p className="mt-3 text-[22px] font-bold leading-none tracking-tight text-ink">micabo</p>
      <p className="mt-1.5 text-[11px] font-medium uppercase tracking-[0.22em] text-ink-tertiary">
        {tagline}
      </p>
    </div>
  );
}
