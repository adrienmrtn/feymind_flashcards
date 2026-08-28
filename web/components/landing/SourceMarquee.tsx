"use client";

import { useState } from "react";

/**
 * Ce qui entre dans Micabo, en une ligne qui défile.
 *
 * Ce n'est pas un mur de logos « ils nous font confiance » - il n'y a pas de clients
 * d'entreprise, et un mur de logos inventés se repère en une seconde. Ce sont les **formats
 * acceptés**, ce qui est une information et non une allégation.
 *
 * Chaque case est assez large pour un vrai exemple (scan, capture, extrait). Les fichiers
 * se déposent dans `web/public/landing/sources/` sous le `id` de la source
 * (`notes-manuscrites.webp`, etc.). Tant qu'ils manquent, un cadre d'attente reste.
 *
 * La bande est dupliquée et translatée de la moitié de sa largeur : c'est ce qui rend la boucle
 * invisible, sans JavaScript ni mesure.
 */

const SOURCES = [
  { id: "polycopie-pdf", emoji: "📄", label: "Polycopié PDF" },
  { id: "photo-notes", emoji: "📸", label: "Photo de tes notes" },
  { id: "document-word", emoji: "📝", label: "Document Word" },
  { id: "video-youtube", emoji: "▶️", label: "Vidéo YouTube" },
  { id: "diapositives", emoji: "🖥️", label: "Diapositives de cours" },
  { id: "manuel-scanne", emoji: "📚", label: "Manuel scanné" },
  { id: "notes-manuscrites", emoji: "✍️", label: "Notes manuscrites" },
] as const;

export function SourceMarquee() {
  return (
    <section className="mt-20 border-y border-hairline-on-canvas py-7" data-print="hide">
      <p className="mb-5 text-center text-[12.5px] text-ink-tertiary">
        Micabo transforme tes documents
      </p>

      <div
        className="relative flex overflow-hidden"
        style={{
          maskImage: "linear-gradient(to right, transparent, black 8%, black 92%, transparent)",
          WebkitMaskImage:
            "linear-gradient(to right, transparent, black 8%, black 92%, transparent)",
        }}
      >
        <div className="marquee-track flex w-max shrink-0 items-stretch gap-4 pr-4">
          {[...SOURCES, ...SOURCES].map((source, index) => (
            <SourceTile key={`${source.id}-${index}`} source={source} />
          ))}
        </div>
      </div>
    </section>
  );
}

function SourceTile({ source }: { source: (typeof SOURCES)[number] }) {
  return (
    <article className="source-tile">
      <SourceExample id={source.id} label={source.label} emoji={source.emoji} />
      <p className="mt-2.5 truncate text-[13.5px] font-medium text-ink">{source.label}</p>
    </article>
  );
}

function SourceExample({
  id,
  label,
  emoji,
}: {
  id: string;
  label: string;
  emoji: string;
}) {
  const [missing, setMissing] = useState(false);

  return (
    <div className="source-tile-frame">
      <div className="source-tile-placeholder">
        <span aria-hidden className="emoji text-[22px]">
          {emoji}
        </span>
        <span className="mt-2 text-[12px] font-medium text-ink-secondary">{label}</span>
        <span className="mt-0.5 text-[11px] text-ink-tertiary">Exemple à venir</span>
      </div>
      {missing ? null : (
        <img
          src={`/landing/sources/${id}.webp`}
          alt=""
          className="source-tile-image absolute inset-0"
          onError={() => setMissing(true)}
        />
      )}
    </div>
  );
}
