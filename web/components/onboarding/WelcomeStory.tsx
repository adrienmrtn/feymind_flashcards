/**
 * La porte : une petite pile de fiches, le mot Micabo dessus.
 *
 * Rien à apprendre encore. Le papier dit déjà de quoi il s'agit.
 * Les décalages sont en `left`/`top`, pas en `translate` : l'entrée
 * `.rise` écraserait sinon la pile en une seule carte.
 */
export function WelcomeStory() {
  return (
    <div
      className="relative mx-auto flex h-full min-h-[300px] w-full max-w-[340px] items-center justify-center"
      aria-hidden
    >
      <div className="absolute inset-x-6 inset-y-8 rounded-sheet bg-canvas-sage" />
      <Sheet offsetX={-34} offsetY={16} angle={-14} depth={0} muted />
      <Sheet offsetX={36} offsetY={12} angle={13} depth={1} muted />
      <Sheet offsetX={0} offsetY={0} angle={-2} depth={2} front />
    </div>
  );
}

function Sheet({
  offsetX,
  offsetY,
  angle,
  depth,
  front = false,
  muted = false,
}: {
  offsetX: number;
  offsetY: number;
  angle: number;
  depth: number;
  front?: boolean;
  muted?: boolean;
}) {
  return (
    <div
      className={`absolute h-[236px] w-[176px] rounded-sheet paper ${
        muted ? "bg-surface-muted" : "bg-surface"
      }`}
      style={{
        zIndex: depth,
        left: `calc(50% + ${offsetX}px)`,
        top: `calc(50% + ${offsetY}px)`,
        transform: `translate(-50%, -50%) rotate(${angle}deg)`,
      }}
    >
      <div className="flex h-full flex-col justify-between px-5 py-6">
        <span
          className="block h-[3px] w-7 rounded-pill"
          style={{ backgroundColor: front ? "var(--color-accent)" : "var(--color-stroke-strong)" }}
        />
        {front ? (
          <div className="flex h-[52px] items-center justify-center rounded-pill bg-ink px-4 text-[17px] font-bold tracking-tight text-on-ink">
            Micabo
          </div>
        ) : (
          <div className="space-y-2">
            <div className="h-[3px] w-full rounded-pill bg-stroke-strong" />
            <div className="h-[3px] w-[88%] rounded-pill bg-stroke" />
            <div className="h-[3px] w-[64%] rounded-pill bg-stroke" />
          </div>
        )}
        <div className="space-y-1.5">
          <div className="h-[3px] w-full rounded-pill bg-stroke" />
          <div className="h-[3px] w-[78%] rounded-pill bg-stroke" />
          <div className="h-[3px] w-[52%] rounded-pill bg-stroke" />
        </div>
      </div>
    </div>
  );
}
