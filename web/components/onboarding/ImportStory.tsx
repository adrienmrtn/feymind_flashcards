"use client";

import { ThinkingOrb } from "thinking-orbs";

import { clamp01, useStoryProgress } from "@/lib/onboarding/use-story-progress";

/**
 * Les formats qu'on dépose, absorbés par Micabo, puis recrachés en fiches.
 *
 * Quatre pages, assez grandes pour se lire : elles partent de la gauche,
 * rejoignent le mot, s'y fondent. Le mot devient l'orbe, et les fiches
 * ressortent comme du papier, pas comme des pastilles.
 */

const DOCS = [
  { id: "pdf", label: "PDF", kind: "pdf" },
  { id: "photo", label: "Photo", kind: "photo" },
  { id: "word", label: "Word", kind: "word" },
  { id: "video", label: "Vidéo", kind: "video" },
] as const;

const SHEETS = [
  {
    title: "Trois temps, une boucle",
    line: "Ce qui s'évapore des océans retombe, puis y retourne.",
  },
  {
    title: "Condensation",
    line: "La vapeur redevient liquide, autour de noyaux.",
  },
  {
    title: "71 % des océans",
    line: "Presque toute l'évaporation part de là.",
  },
] as const;

const DURATION_MS = 8_400;

export function ImportStory() {
  const progress = useStoryProgress(DURATION_MS);
  const thinking = progress >= 0.52 && progress < 0.78;
  const sheetsOut = progress >= 0.74;
  const logoGone = progress >= 0.52;

  return (
    <div className="relative mx-auto h-[min(52svh,400px)] w-full max-w-[440px]" aria-hidden>
      {DOCS.map((doc, index) => (
        <DocTile key={doc.id} doc={doc} index={index} progress={progress} />
      ))}

      <div
        className="absolute left-1/2 top-1/2 flex h-[52px] -translate-x-1/2 -translate-y-1/2 items-center justify-center rounded-pill bg-ink px-5 text-[16px] font-bold tracking-tight text-on-ink"
        style={{
          opacity: logoGone ? 0 : 1,
          transform: `translate(-50%, -50%) scale(${logoGone ? 0.84 : 1})`,
          transition:
            "opacity 320ms var(--ease-out-strong), transform 320ms var(--ease-out-strong)",
        }}
      >
        Micabo
      </div>

      <div
        className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2"
        style={{
          opacity: thinking || sheetsOut ? 1 : 0,
          transform: `translate(-50%, -50%) scale(${sheetsOut ? 0.92 : 1})`,
          transition:
            "opacity 280ms var(--ease-out-strong), transform 280ms var(--ease-out-strong)",
        }}
      >
        <ThinkingOrb state={sheetsOut ? "composing" : "searching"} size={64} />
      </div>

      {SHEETS.map((sheet, index) => {
        const local = clamp01((progress - 0.74 - index * 0.055) / 0.14);
        const angle = -16 + index * 16;
        const x = (-18 + index * 18) * local;
        const y = 96 + Math.abs(index - 1) * 6;
        return (
          <article
            key={sheet.title}
            className="paper pointer-events-none absolute left-1/2 top-1/2 w-[168px] rounded-[16px] bg-surface px-3.5 py-3"
            style={{
              opacity: local,
              transform: `translate(calc(-50% + ${x}px), calc(-50% + ${y * local}px)) rotate(${angle}deg)`,
            }}
          >
            <span className="mb-2 block h-[3px] w-6 rounded-pill bg-accent" />
            <p className="text-[13px] font-semibold leading-snug text-ink">{sheet.title}</p>
            <p className="mt-1 text-[11px] leading-snug text-ink-secondary">{sheet.line}</p>
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
  const appear = clamp01((progress - index * 0.05) / 0.2);
  const converge = clamp01((progress - 0.28) / 0.22);
  const absorb = clamp01((progress - 0.5) / 0.08);

  const startX = -150;
  const startY = -118 + index * 78;
  const x = startX * (1 - converge);
  const y = startY * (1 - converge);
  const scale = (0.92 + appear * 0.08) * (1 - absorb * 0.55);
  const opacity = appear * (1 - absorb);

  return (
    <div
      className="absolute left-1/2 top-1/2"
      style={{
        opacity,
        transform: `translate(calc(-50% + ${x}px), calc(-50% + ${y}px)) scale(${scale})`,
        zIndex: 2,
      }}
    >
      <DocumentFace kind={doc.kind} />
      <p className="mt-1.5 text-center text-[11px] font-medium text-ink-secondary">{doc.label}</p>
    </div>
  );
}

function DocumentFace({ kind }: { kind: (typeof DOCS)[number]["kind"] }) {
  if (kind === "pdf") {
    return (
      <div className="relative h-[102px] w-[78px] overflow-hidden rounded-[10px] bg-surface paper">
        <span className="absolute right-0 top-0 h-4 w-4 bg-negative-soft" />
        <div className="px-2.5 pt-6">
          <div className="h-[3px] w-7 rounded-pill bg-ink" />
          <div className="mt-2 space-y-1">
            <div className="h-[2px] w-full rounded-pill bg-stroke-strong" />
            <div className="h-[2px] w-[90%] rounded-pill bg-stroke" />
            <div className="h-[2px] w-[70%] rounded-pill bg-stroke" />
            <div className="h-[2px] w-[82%] rounded-pill bg-stroke" />
          </div>
        </div>
        <span className="absolute bottom-1.5 left-2 text-[8px] font-bold tracking-caps text-negative">
          PDF
        </span>
      </div>
    );
  }

  if (kind === "photo") {
    return (
      <div className="h-[102px] w-[78px] rotate-[-4deg] rounded-[10px] bg-surface px-1.5 pb-2.5 pt-1.5 paper">
        <div className="flex h-[70px] items-end justify-center overflow-hidden rounded-[6px] bg-canvas-sage">
          <span className="mb-1.5 h-8 w-8 rounded-full bg-accent-soft" />
        </div>
      </div>
    );
  }

  if (kind === "word") {
    return (
      <div className="relative h-[102px] w-[78px] overflow-hidden rounded-[10px] bg-surface paper">
        <div className="h-5 bg-info-soft" />
        <div className="px-2 pt-2.5">
          <div className="h-[3px] w-8 rounded-pill bg-info" />
          <div className="mt-2 space-y-1">
            <div className="h-[2px] w-full rounded-pill bg-stroke-strong" />
            <div className="h-[2px] w-[86%] rounded-pill bg-stroke" />
            <div className="h-[2px] w-[74%] rounded-pill bg-stroke" />
          </div>
        </div>
        <span className="absolute bottom-1.5 left-2 text-[8px] font-bold tracking-caps text-info">
          DOC
        </span>
      </div>
    );
  }

  return (
    <div className="relative h-[102px] w-[82px] overflow-hidden rounded-[10px] bg-ink paper">
      <div className="absolute inset-x-2 top-2 h-8 rounded-[4px] bg-on-ink/10" />
      <span className="absolute left-1/2 top-[38px] flex h-7 w-7 -translate-x-1/2 items-center justify-center rounded-full bg-on-ink/15">
        <svg viewBox="0 0 12 12" className="ml-0.5 h-3 w-3 text-on-ink" aria-hidden>
          <path d="M3 2.2v7.6L10 6z" fill="currentColor" />
        </svg>
      </span>
      <span className="absolute bottom-1.5 left-2 text-[8px] font-bold tracking-caps text-on-ink-muted">
        VIDÉO
      </span>
    </div>
  );
}
