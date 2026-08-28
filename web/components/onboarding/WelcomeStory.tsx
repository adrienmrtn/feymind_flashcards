/**
 * La porte : une petite pile de fiches, le mot Micabo dessus.
 *
 * Rien à apprendre encore. Le papier dit déjà de quoi il s'agit.
 */
export function WelcomeStory() {
  return (
    <div
      className="relative mx-auto flex h-full min-h-[280px] w-full max-w-[300px] items-center justify-center"
      aria-hidden
    >
      <Sheet offsetX={-22} offsetY={10} angle={-12} delay={0} depth={0} muted />
      <Sheet offsetX={24} offsetY={8} angle={11} delay={90} depth={1} muted />
      <Sheet offsetX={0} offsetY={0} angle={-1.5} delay={180} depth={2} front />
    </div>
  );
}

function Sheet({
  offsetX,
  offsetY,
  angle,
  delay,
  depth,
  front = false,
  muted = false,
}: {
  offsetX: number;
  offsetY: number;
  angle: number;
  delay: number;
  depth: number;
  front?: boolean;
  muted?: boolean;
}) {
  return (
    <div
      className={`absolute h-[236px] w-[180px] rounded-sheet paper ${
        muted ? "bg-surface-muted" : "bg-surface"
      }`}
      style={{
        zIndex: depth,
        transform: `translate(${offsetX}px, ${offsetY}px) rotate(${angle}deg)`,
        animation: `micabo-rise 480ms var(--ease-out-strong) ${delay}ms both`,
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
