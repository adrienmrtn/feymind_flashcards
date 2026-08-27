"use client";

import { useEffect, useRef, useState } from "react";

import { DEMO_COURSE } from "@/components/demo/demo-course";

/**
 * **Le geste de l'import, fait à la main.**
 *
 * L'écran disait « tu déposes ton cours » en montrant une page immobile. Ici on dépose : on prend
 * la vignette du PDF et on la lâche dans la zone. C'est le même geste que l'import réel du web —
 * le glisser-déposer y remplace le scanner — donc la démonstration apprend quelque chose au lieu
 * de l'illustrer.
 *
 * Le pointeur plutôt que l'API de glisser-déposer HTML : `dragstart` n'existe pas sur un écran
 * tactile, et un geste qui ne marche qu'à la souris est un geste que la moitié des visiteurs ne
 * peut pas faire. Les événements de pointeur couvrent les deux, et `setPointerCapture` garde le
 * suivi même quand le doigt sort de la vignette.
 *
 * Le clavier a sa propre voie : la vignette est un `<button>`, et Entrée dépose. Une interaction
 * qui n'existe qu'au geste est une interaction inaccessible.
 *
 * **S'il ne se passe rien**, on n'attend pas indéfiniment. Deux secondes sans mouvement : on dit
 * exactement quoi faire. Cinq secondes : le PDF fait le geste tout seul.
 */
export function DropDemo({ onDropped }: { onDropped: () => void }) {
  const zone = useRef<HTMLDivElement>(null);
  const thumb = useRef<HTMLButtonElement>(null);
  const lastMove = useRef(typeof performance === "undefined" ? 0 : performance.now());
  const dragging = useRef(false);
  const finished = useRef(false);
  const autoPlayed = useRef(false);

  const [offset, setOffset] = useState<{ x: number; y: number } | null>(null);
  const [over, setOver] = useState(false);
  const [dropped, setDropped] = useState(false);
  const [hint, setHint] = useState(false);
  const [auto, setAuto] = useState(false);
  const origin = useRef({ x: 0, y: 0 });

  function finish() {
    if (finished.current) return;
    finished.current = true;
    setDropped(true);
    setOffset(null);
    setOver(false);
    setHint(false);
    setAuto(false);
    onDropped();
  }

  function begin(event: React.PointerEvent<HTMLButtonElement>) {
    if (dropped || auto) return;
    event.currentTarget.setPointerCapture(event.pointerId);
    origin.current = { x: event.clientX, y: event.clientY };
    dragging.current = true;
    setHint(false);
    setOffset({ x: 0, y: 0 });
  }

  function move(event: React.PointerEvent<HTMLButtonElement>) {
    if (!offset || dropped || auto) return;
    const next = {
      x: event.clientX - origin.current.x,
      y: event.clientY - origin.current.y,
    };
    setOffset(next);

    const bounds = zone.current?.getBoundingClientRect();
    setOver(
      Boolean(
        bounds &&
          event.clientX > bounds.left &&
          event.clientX < bounds.right &&
          event.clientY > bounds.top &&
          event.clientY < bounds.bottom,
      ),
    );
  }

  function end() {
    if (dropped || auto) return;
    dragging.current = false;
    if (over) {
      finish();
      return;
    }
    // Manqué : la vignette revient à sa place plutôt que de rester là où on l'a lâchée.
    setOffset(null);
    setOver(false);
  }

  function playAuto() {
    if (finished.current || autoPlayed.current) return;
    autoPlayed.current = true;
    setHint(false);
    setAuto(true);

    const zoneBox = zone.current?.getBoundingClientRect();
    const thumbBox = thumb.current?.getBoundingClientRect();
    if (!zoneBox || !thumbBox) {
      finish();
      return;
    }

    const dx = zoneBox.left + zoneBox.width / 2 - (thumbBox.left + thumbBox.width / 2);
    const dy = zoneBox.top + zoneBox.height / 2 - (thumbBox.top + thumbBox.height / 2);
    setOffset({ x: 0, y: 0 });
    setOver(true);
    requestAnimationFrame(() => {
      setOffset({ x: dx, y: dy });
    });
    window.setTimeout(() => {
      finish();
    }, 720);
  }

  useEffect(() => {
    lastMove.current = performance.now();

    function mark() {
      if (finished.current || dragging.current || autoPlayed.current) return;
      lastMove.current = performance.now();
      setHint(false);
    }

    const watching: Array<keyof WindowEventMap> = ["pointermove", "pointerdown", "keydown"];
    for (const name of watching) {
      window.addEventListener(name, mark, { passive: true });
    }

    const tick = window.setInterval(() => {
      if (finished.current || dragging.current || autoPlayed.current) return;
      const idle = performance.now() - lastMove.current;
      if (idle >= 5_000) playAuto();
      else if (idle >= 2_000) setHint(true);
    }, 200);

    return () => {
      for (const name of watching) window.removeEventListener(name, mark);
      window.clearInterval(tick);
    };
    // Le minuteur vit pour toute la vie du geste : le relancer à chaque pixel
    // remettrait le compte à zéro plus souvent que le mouvement lui-même.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const active = over || Boolean(offset);

  return (
    <div className="flex flex-col items-center gap-4">
      <div
        ref={zone}
        className={`relative flex h-[220px] w-full max-w-[420px] flex-col items-center justify-center rounded-group border-2 border-dashed transition-all duration-menu ease-out-strong ${
          dropped
            ? "border-accent bg-accent-soft"
            : over
              ? "scale-[1.02] border-accent bg-accent-soft"
              : "border-stroke-strong bg-surface-muted"
        }`}
        aria-live="polite"
      >
        {dropped ? (
          <>
            <span aria-hidden className="emoji text-[28px]">
              ✅
            </span>
            <p className="mt-2.5 text-[15px] font-semibold text-accent">{DEMO_COURSE.fileName}</p>
            <p className="mt-1 text-[13px] text-ink-secondary">Micabo le lit…</p>
          </>
        ) : (
          <>
            <span
              aria-hidden
              className={`absolute inset-3 rounded-[20px] transition-opacity duration-menu ${
                active ? "opacity-100" : "opacity-0"
              }`}
              style={{ background: "var(--color-accent-vivid)", opacity: active ? 0.08 : 0 }}
            />
            <svg
              aria-hidden
              viewBox="0 0 24 24"
              className={`h-8 w-8 transition-colors duration-hover ${
                active ? "text-accent" : "float text-ink-tertiary"
              }`}
            >
              <path
                d="M12 16V4M7 9l5-5 5 5M4 17v2a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-2"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.6"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
            <p className="mt-3 text-[15.5px] font-semibold text-ink">
              {active ? "Lâche-le ici" : "Glisse le PDF ici"}
            </p>
            <p className="mt-1 text-[12.5px] text-ink-tertiary">
              {active ? "\u00a0" : "Attrape-le juste en dessous"}
            </p>
          </>
        )}
      </div>

      {dropped ? null : (
        <>
          <svg
            aria-hidden
            viewBox="0 0 24 40"
            className={`h-8 w-5 text-ink-tertiary transition-opacity duration-hover ${
              offset ? "opacity-0" : "opacity-100"
            }`}
          >
            <path
              d="M12 36V6M5 13l7-7 7 7"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.6"
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeDasharray="3 4"
            />
          </svg>

          <button
            ref={thumb}
            type="button"
            onPointerDown={begin}
            onPointerMove={move}
            onPointerUp={end}
            onPointerCancel={end}
            onKeyDown={(event) => {
              if (event.key !== "Enter" && event.key !== " ") return;
              event.preventDefault();
              finish();
            }}
            aria-label={`Déposer ${DEMO_COURSE.fileName}`}
            className={`flex touch-none items-center gap-3 rounded-button bg-surface px-4 py-3.5 paper ${
              offset ? "cursor-grabbing" : "shiny-loud cursor-grab"
            }`}
            style={{
              translate: offset ? `${offset.x}px ${offset.y}px` : undefined,
              transition: auto
                ? "translate 680ms var(--ease-out-strong), scale 680ms var(--ease-out-strong)"
                : offset
                  ? "none"
                  : "translate 320ms var(--ease-out-strong)",
              scale: offset ? 1.06 : 1,
              rotate: offset ? "-2deg" : "0deg",
              boxShadow: offset ? "var(--shadow-floating)" : undefined,
              zIndex: offset ? 2 : undefined,
            }}
          >
            <span aria-hidden className="text-ink-tertiary">
              <svg viewBox="0 0 20 20" className="h-4 w-4">
                <circle cx="6" cy="5" r="1.4" fill="currentColor" />
                <circle cx="6" cy="10" r="1.4" fill="currentColor" />
                <circle cx="6" cy="15" r="1.4" fill="currentColor" />
                <circle cx="12" cy="5" r="1.4" fill="currentColor" />
                <circle cx="12" cy="10" r="1.4" fill="currentColor" />
                <circle cx="12" cy="15" r="1.4" fill="currentColor" />
              </svg>
            </span>
            <span className="flex h-10 w-8 items-center justify-center rounded-[5px] bg-[#B5573C] text-[10px] font-bold tracking-[0.8px] text-on-ink">
              PDF
            </span>
            <span className="text-[14px] font-medium text-ink">{DEMO_COURSE.fileName}</span>
          </button>

          {hint && !offset ? (
            <p
              role="status"
              className="rise paper max-w-[40ch] rounded-group bg-caution-soft px-4 py-3 text-center text-[13.5px] leading-relaxed text-ink"
            >
              Prends le PDF <span className="font-semibold">en bas</span>,
              glisse-le jusqu&apos;à la zone en pointillés{" "}
              <span className="font-semibold">juste au-dessus</span>, puis
              lâche-le.
            </p>
          ) : null}
        </>
      )}
    </div>
  );
}
