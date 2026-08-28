"use client";

import { useEffect, useState } from "react";
import { ThinkingOrb } from "thinking-orbs";

/**
 * Les formats qu'on dépose, absorbés par Micabo, puis recrachés en fiches.
 *
 * Les cases cherchent le même fichier que la vitrine
 * (`/landing/sources/{id}.webp`). Tant qu'il manque, l'emoji tient la place.
 */

const DOCS = [
  { id: "polycopie-pdf", emoji: "📄", label: "PDF" },
  { id: "photo-notes", emoji: "📸", label: "Photo" },
  { id: "document-word", emoji: "📝", label: "Word" },
  { id: "video-youtube", emoji: "▶️", label: "Vidéo" },
  { id: "diapositives", emoji: "🖥️", label: "Diapos" },
  { id: "notes-manuscrites", emoji: "✍️", label: "Notes" },
] as const;

const SHEETS = [
  { title: "Le cycle de l'eau", line: "Évaporation, condensation, pluie." },
  { title: "Les trois temps", line: "Une boucle, jamais perdue." },
  { title: "D'où vient l'eau", line: "71 % depuis les océans." },
] as const;

const DURATION_MS = 7_200;

export function ImportStory() {
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      setProgress(1);
      return;
    }

    const started = Date.now();
    let frame = 0;

    function tick() {
      const next = Math.min(1, (Date.now() - started) / DURATION_MS);
      setProgress(next);
      if (next >= 1) return;
      frame = window.requestAnimationFrame(tick);
    }

    frame = window.requestAnimationFrame(tick);
    return () => window.cancelAnimationFrame(frame);
  }, []);

  const thinking = progress >= 0.58 && progress < 0.78;
  const sheets = progress >= 0.76;
  const logoGone = progress >= 0.58;

  return (
    <div className="relative mx-auto h-[min(42svh,340px)] w-full max-w-[420px]" aria-hidden>
      {DOCS.map((doc, index) => (
        <DocTile key={doc.id} doc={doc} index={index} progress={progress} />
      ))}

      <div
        className="absolute left-1/2 top-1/2 flex h-12 -translate-x-1/2 -translate-y-1/2 items-center justify-center rounded-pill bg-ink px-4 text-[14px] font-bold tracking-tight text-on-ink"
        style={{
          opacity: logoGone ? 0 : 1,
          transform: `translate(-50%, -50%) scale(${logoGone ? 0.72 : 1})`,
          transition: "opacity 280ms var(--ease-out-strong), transform 280ms var(--ease-out-strong)",
        }}
      >
        Micabo
      </div>

      <div
        className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2"
        style={{
          opacity: thinking || sheets ? 1 : 0,
          transition: "opacity 240ms var(--ease-out-strong)",
        }}
      >
        <ThinkingOrb state={sheets ? "composing" : "searching"} size={64} />
      </div>

      {SHEETS.map((sheet, index) => {
        const local = Math.min(1, Math.max(0, (progress - 0.76 - index * 0.05) / 0.12));
        const angle = (-18 + index * 18) * (Math.PI / 180);
        const distance = 108 * local;
        return (
          <article
            key={sheet.title}
            className="paper pointer-events-none absolute left-1/2 top-1/2 w-[148px] rounded-tile bg-surface px-3 py-2.5"
            style={{
              opacity: local,
              transform: `translate(calc(-50% + ${Math.sin(angle) * distance}px), calc(-50% + ${-Math.cos(angle) * distance + 24}px)) rotate(${-10 + index * 10}deg)`,
            }}
          >
            <p className="text-[11px] font-semibold leading-tight text-ink">{sheet.title}</p>
            <p className="mt-1 text-[10px] leading-snug text-ink-tertiary">{sheet.line}</p>
            <div className="mt-2 h-1 overflow-hidden rounded-pill bg-progress-track">
              <div className="h-full w-2/3 rounded-pill bg-progress" />
            </div>
          </article>
        );
      })}
    </div>
  );
}

function DocTile({
  doc,
  index,
  progress,
}: {
  doc: (typeof DOCS)[number];
  index: number;
  progress: number;
}) {
  const appear = clamp((progress - index * 0.045) / 0.22);
  const converge = clamp((progress - 0.34) / 0.22);
  const absorb = clamp((progress - 0.54) / 0.08);

  const startX = -168 - (index % 3) * 10;
  const startY = -92 + index * 34;
  const x = startX * (1 - converge);
  const y = startY * (1 - converge);
  const scale = (0.94 + appear * 0.06) * (1 - absorb);
  const opacity = appear * (1 - absorb);

  return (
    <div
      className="absolute left-1/2 top-1/2"
      style={{
        opacity,
        transform: `translate(calc(-50% + ${x}px), calc(-50% + ${y}px)) scale(${scale})`,
      }}
    >
      <SourceGlyph id={doc.id} emoji={doc.emoji} />
      <p className="mt-1 text-center text-[9px] font-medium text-ink-secondary">{doc.label}</p>
    </div>
  );
}

function SourceGlyph({ id, emoji }: { id: string; emoji: string }) {
  const [ready, setReady] = useState(false);
  const src = `/landing/sources/${id}.webp`;

  useEffect(() => {
    const probe = new window.Image();
    probe.onload = () => setReady(true);
    probe.src = src;
    return () => {
      probe.onload = null;
    };
  }, [src]);

  return (
    <div className="flex h-14 w-[3.35rem] items-center justify-center overflow-hidden rounded-[10px] bg-surface shadow-[0_0_0_1px_oklch(0_0_0/0.1)]">
      {ready ? (
        <img src={src} alt="" className="h-full w-full object-cover" />
      ) : (
        <span className="emoji text-[22px]">{emoji}</span>
      )}
    </div>
  );
}

function clamp(value: number) {
  return Math.min(1, Math.max(0, value));
}
