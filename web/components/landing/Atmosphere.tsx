/**
 * **Le lavage d'ambiance** : trois taches de couleur qui dérivent très lentement, et un grain.
 *
 * Aucun shader, aucun flou : des dégradés radiaux qu'on déplace en `transform`, donc un coût
 * de composition et rien d'autre. Les couleurs sont les jetons de Micabo (le bleu, le lilas
 * et la menthe des tons de leçon) : elles basculent avec la nuit et le crépuscule.
 *
 * `boxed` la tient dans une boîte (l'appel final, la connexion) au lieu du haut de page.
 */
export function Atmosphere({ boxed = false }: { boxed?: boolean }) {
  return (
    <div aria-hidden data-print="hide" className={boxed ? "lp-atmos lp-atmos-box" : "lp-atmos"}>
      <div className="lp-blob lp-blob-a" />
      <div className="lp-blob lp-blob-b" />
      <div className="lp-blob lp-blob-c" />
      <div className="lp-grain" />
    </div>
  );
}
