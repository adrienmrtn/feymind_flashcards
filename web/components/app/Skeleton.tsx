/**
 * Ce qu'on montre pendant qu'une page se fabrique.
 *
 * Sans ça, chaque changement d'écran attend le retour de Supabase **avant de peindre quoi que ce
 * soit** : le clic reste sans effet une demi-seconde, et l'app se lit comme lente alors qu'elle
 * attend le réseau. Une charpente aux bonnes dimensions rend la navigation immédiate, et évite en
 * plus le saut de mise en page à l'arrivée des vraies données.
 *
 * Elle ne pulse pas : un fond qui clignote sur chaque écran devient le mouvement le plus vu du
 * produit, et la table des fréquences dit que c'est là qu'il faut se retenir.
 */
export function Bar({ className = "" }: { className?: string }) {
  return <div className={`rounded-[8px] bg-surface-muted ${className}`} />;
}

export function CardSkeleton({ rows = 3 }: { rows?: number }) {
  return (
    <div className="paper rounded-group bg-surface p-5">
      {Array.from({ length: rows }, (_, index) => (
        <div key={index} className={index > 0 ? "mt-3.5" : ""}>
          <Bar className="h-4 w-[46%]" />
          <Bar className="mt-2 h-3 w-[72%]" />
        </div>
      ))}
    </div>
  );
}

export function HeaderSkeleton() {
  return (
    <header>
      <Bar className="h-3 w-24" />
      <Bar className="mt-3 h-8 w-[54%]" />
    </header>
  );
}
