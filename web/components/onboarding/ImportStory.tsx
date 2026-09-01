"use client";

import { useEffect, useState } from "react";

import { BrandMark } from "@/components/BrandMark";

/**
 * Les formats qu'on dépose, absorbés par Micabo. **Un seul temps.**
 *
 * Les cases convergent vers l'icône Micabo, passent **derrière**, et c'est
 * fini. Rien après : la fiche qui en sort a son propre écran, et la raconter
 * deux fois faisait deux animations dans une seule. Le mot et le sous-titre
 * restent sur l'accueil : ici, seule l'image tient le centre.
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

/** Une seule respiration, et lente : on la regarde une fois, sans rien à faire. */
const DURATION_MS = 5_600;

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
      const elapsed = (Date.now() - started) % (DURATION_MS + 900);
      const next = Math.min(1, elapsed / DURATION_MS);
      setProgress(next);
      frame = window.requestAnimationFrame(tick);
    }

    frame = window.requestAnimationFrame(tick);
    return () => window.cancelAnimationFrame(frame);
  }, []);

  return (
    <div
      className="relative mx-auto flex h-full min-h-[240px] w-full max-w-[420px] flex-1 items-center justify-center"
      aria-hidden
    >
      {/*
        Le logo est dans le flux, dans une vraie boîte 104px. Une ancre
        `h-0 w-0` le posait au centre géométrique d'une scène trop haute
        pour la carte : les documents se voyaient, l'icône passait sous le
        pli (ou se faisait clipper par le défilement du Scaffold).
      */}
      <div className="relative z-10 size-[104px] shrink-0">
        <div className="absolute left-1/2 top-1/2">
          {DOCS.map((doc, index) => (
            <DocTile key={doc.id} doc={doc} index={index} progress={progress} />
          ))}
        </div>
        <BrandMark size={104} />
      </div>
    </div>
  );
}

/**
 * Une case qui vient de son coin, glisse vers le logo, et **passe dessous.**
 *
 * Elle ne disparaît pas en fondu à distance : elle rétrécit en arrivant au
 * centre, ce qui se lit comme « avalé » et non comme « effacé ».
 */
function DocTile({
  doc,
  index,
  progress,
}: {
  doc: (typeof DOCS)[number];
  index: number;
  progress: number;
}) {
  const appear = clamp((progress - index * 0.05) / 0.2);
  const converge = ease(clamp((progress - 0.24 - index * 0.045) / 0.5));

  const angle = (index / DOCS.length) * Math.PI * 2 - Math.PI / 2;
  const radius = 168;
  const startX = Math.cos(angle) * radius;
  const startY = Math.sin(angle) * radius * 0.78;

  const x = startX * (1 - converge);
  const y = startY * (1 - converge);
  // Elle garde sa taille presque jusqu'au bout, puis se referme sur le logo.
  const shrink = clamp((converge - 0.72) / 0.28);
  const scale = (0.92 + appear * 0.08) * (1 - shrink * 0.55);

  return (
    <div
      className="absolute left-0 top-0 z-0"
      style={{
        opacity: appear * (1 - shrink),
        transform: `translate(calc(-50% + ${x}px), calc(-50% + ${y}px)) scale(${scale})`,
      }}
    >
      <SourceGlyph id={doc.id} emoji={doc.emoji} />
      <p className="mt-1 text-center text-[9.5px] font-medium text-ink-secondary">{doc.label}</p>
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

/** Un départ franc, une arrivée posée. */
function ease(value: number) {
  return 1 - Math.pow(1 - value, 3);
}
