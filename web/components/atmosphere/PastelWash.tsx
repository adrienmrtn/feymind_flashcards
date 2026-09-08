/**
 * Nappe de taches pastel, derrière le papier.
 *
 * Elle ne s'allume que si `html` porte `data-pastel="on"` — le même
 * interrupteur que les jetons. Sans ça, elle ne peint rien.
 */
export function PastelWash() {
  return <div aria-hidden data-print="hide" className="pastel-wash" />;
}
