import type { Route } from "next";
import Link from "next/link";

/**
 * Le stylo, coins arrondis. C'est le même fichier que le favicon.
 *
 * L'image a déjà son masque : on ne re-coupe pas en CSS, sinon le rayon du
 * fichier et celui du navigateur se disputent d'un pixel.
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
      className={`shrink-0 ${className}`.trim()}
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
