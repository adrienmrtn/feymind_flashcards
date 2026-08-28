/**
 * La porte : une petite pile de fiches, le mot Micabo dessus.
 *
 * Rien à apprendre encore. Le papier dit déjà de quoi il s'agit.
 */
export function WelcomeStory() {
  return (
    <div
      className="relative mx-auto flex h-[min(46svh,360px)] w-full max-w-[280px] items-center justify-center"
      aria-hidden
    >
      <Sheet angle={-10} delay={0} depth={0} />
      <Sheet angle={8} delay={90} depth={1} />
      <Sheet angle={-1.5} delay={180} depth={2} front />
    </div>
  );
}

function Sheet({
  angle,
  delay,
  depth,
  front = false,
}: {
  angle: number;
  delay: number;
  depth: number;
  front?: boolean;
}) {
  return (
    <div
      className="paper rise absolute h-[228px] w-[176px] rounded-sheet bg-surface"
      style={{
        zIndex: depth,
        rotate: `${angle}deg`,
        animationDelay: `${delay}ms`,
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
