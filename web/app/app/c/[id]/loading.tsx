import { Bar, CardSkeleton, HeaderSkeleton } from "@/components/app/Skeleton";

/**
 * Le squelette d'un cours qui s'ouvre.
 *
 * Il portait un cas de plus : quand la fiche venait d'être écrite, l'écran affichait le
 * pourcentage de l'écriture au lieu du squelette. L'attente ne quitte plus le panneau
 * d'import, donc arriver ici veut dire une seule chose - la page charge - et un squelette la
 * dit mieux qu'un compteur qui repart de zéro.
 */
export default function Loading() {
  return (
    <>
      <HeaderSkeleton />
      <div className="mt-8 space-y-3">
        <CardSkeleton rows={3} />
        <Bar className="h-32" />
        <CardSkeleton rows={2} />
      </div>
    </>
  );
}
