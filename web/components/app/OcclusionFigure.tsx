/**
 * Schéma d'une carte à occlusion. La zone à trouver est couverte d'un cache à
 * l'accent au recto ; au verso le cache se lève et laisse un cadre.
 *
 * Les coordonnées sont relatives (0…1) : le même schéma se rend correctement
 * en session, en liste ou dans l'éditeur.
 */
export function OcclusionFigure({
  image,
  mask,
  revealed,
}: {
  image: string;
  mask: { x: number; y: number; width: number; height: number };
  revealed: boolean;
}) {
  const left = `${clamp(mask.x) * 100}%`;
  const top = `${clamp(mask.y) * 100}%`;
  const width = `${Math.max(0.02, clamp(mask.width)) * 100}%`;
  const height = `${Math.max(0.02, clamp(mask.height)) * 100}%`;

  return (
    <div
      className="relative inline-block max-h-[260px] overflow-hidden rounded-md"
      aria-label={revealed ? "Schéma, zone révélée" : "Schéma, une zone est masquée"}
    >
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={image} alt="" className="block max-h-[260px] w-auto max-w-full" />
      <div
        className={`absolute flex items-center justify-center rounded-[6px] ${
          revealed ? "bg-accent/12 ring-2 ring-accent" : "bg-accent"
        }`}
        style={{ left, top, width, height, minWidth: 12, minHeight: 12 }}
      >
        {revealed ? null : (
          <span className="text-[15px] font-bold text-on-ink" aria-hidden>
            ?
          </span>
        )}
      </div>
    </div>
  );
}

function clamp(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.min(1, Math.max(0, value));
}
