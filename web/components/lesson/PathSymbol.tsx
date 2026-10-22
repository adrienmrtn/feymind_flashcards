import { pathSymbolIcon } from "@/lib/lesson/path-symbols";

/**
 * **Le pictogramme d'un rond du chemin**, au trait.
 *
 * Décoratif : le titre de l'étape, à côté, dit ce qu'elle est. La couleur vient du parent
 * (`currentColor`), parce que c'est l'état du rond — fait, en cours, à venir — qui la décide.
 */
export function PathSymbol({
  id,
  size = 28,
  strokeWidth = 2,
  className,
}: {
  id: string | null | undefined;
  size?: number;
  strokeWidth?: number;
  className?: string;
}) {
  const Icon = pathSymbolIcon(id);
  return <Icon aria-hidden="true" width={size} height={size} strokeWidth={strokeWidth} className={className} />;
}
