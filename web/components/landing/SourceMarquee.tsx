/**
 * Ce qui entre dans Micabo, en une ligne qui défile.
 *
 * Ce n'est pas un mur de logos « ils nous font confiance » — il n'y a pas de clients
 * d'entreprise, et un mur de logos inventés se repère en une seconde. Ce sont les **formats
 * acceptés**, ce qui est une information et non une allégation.
 *
 * La bande est dupliquée et translatée de la moitié de sa largeur : c'est ce qui rend la boucle
 * invisible, sans JavaScript ni mesure.
 */

const SOURCES = [
  "Polycopié PDF",
  "Photo de tes notes",
  "Document Word",
  "Vidéo YouTube",
  "Diapositives de cours",
  "Manuel scanné",
  "Notes manuscrites",
];

export function SourceMarquee() {
  return (
    <section className="mt-20 border-y border-hairline-on-canvas py-5" data-print="hide">
      <p className="mb-4 text-center text-[12.5px] text-ink-tertiary">
        Tout ce que Micabo sait lire
      </p>

      <div
        className="relative flex overflow-hidden"
        style={{
          maskImage:
            "linear-gradient(to right, transparent, black 12%, black 88%, transparent)",
          WebkitMaskImage:
            "linear-gradient(to right, transparent, black 12%, black 88%, transparent)",
        }}
      >
        <div className="marquee-track flex w-max shrink-0 items-center gap-3">
          {[...SOURCES, ...SOURCES].map((source, index) => (
            <span
              key={index}
              className="whitespace-nowrap rounded-pill bg-surface px-4 py-2 text-[13.5px] font-medium text-ink-secondary paper"
            >
              {source}
            </span>
          ))}
        </div>
      </div>
    </section>
  );
}
