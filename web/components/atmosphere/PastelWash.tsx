/**
 * Nappe de taches pastel, derrière le papier de l'app.
 *
 * Elle ne s'allume que si `.app-shell` porte `data-pastel="on"`.
 */
export function PastelWash() {
  return <div aria-hidden data-print="hide" className="pastel-wash" />;
}
