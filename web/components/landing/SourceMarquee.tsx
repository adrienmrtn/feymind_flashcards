"use client";

import { useI18n } from "@/lib/i18n/client";

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
 * On ne sonde pas le réseau pour le savoir : un `.webp` absent est une 404 que
 * Google compte comme une ressource de page manquante.
 *
 * La bande est dupliquée et translatée de la moitié de sa largeur : c'est ce qui rend la boucle
 * invisible, sans JavaScript ni mesure.
 */

const SOURCES = [
  { id: "polycopie-pdf", emoji: "📄", labelKey: "landing.sourcePdf" },
  { id: "photo-notes", emoji: "📸", labelKey: "landing.sourcePhoto" },
  { id: "document-word", emoji: "📝", labelKey: "landing.sourceWord" },
  { id: "video-youtube", emoji: "▶️", labelKey: "landing.sourceYoutube" },
  { id: "diapositives", emoji: "🖥️", labelKey: "landing.sourceSlides" },
  { id: "manuel-scanne", emoji: "📚", labelKey: "landing.sourceScan" },
  { id: "notes-manuscrites", emoji: "✍️", labelKey: "landing.sourceNotes" },
] as const;

export function SourceMarquee({
  availableIds = [],
}: {
  availableIds?: readonly string[];
}) {
  const present = new Set(availableIds);
  const { t } = useI18n();

  return (
    <section className="mt-20 border-y border-hairline-on-canvas py-7" data-print="hide">
      <p className="mb-5 text-center text-[12.5px] text-ink-tertiary">
        {t("landing.sourcesHeading")}
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
            <SourceTile
              key={`${source.id}-${index}`}
              source={source}
              label={t(source.labelKey)}
              soon={t("landing.sourceSoon")}
              src={present.has(source.id) ? `/landing/sources/${source.id}.webp` : null}
            />
          ))}
        </div>
      </div>
    </section>
  );
}

function SourceTile({
  source,
  src,
  label,
  soon,
}: {
  source: (typeof SOURCES)[number];
  src: string | null;
  label: string;
  soon: string;
}) {
  return (
    <article className="source-tile">
      <SourceExample src={src} label={label} soon={soon} emoji={source.emoji} />
      <p className="mt-2.5 truncate text-[13.5px] font-medium text-ink">{label}</p>
    </article>
  );
}

function SourceExample({
  src,
  label,
  soon,
  emoji,
}: {
  src: string | null;
  label: string;
  soon: string;
  emoji: string;
}) {
  return (
    <div className="source-tile-frame">
      {src ? (
        <img src={src} alt="" className="source-tile-image" />
      ) : (
        <div className="source-tile-placeholder">
          <span aria-hidden className="emoji text-[28px]">
            {emoji}
          </span>
          <span className="mt-2.5 text-[13px] font-medium text-ink-secondary">{label}</span>
          <span className="mt-0.5 text-[12px] text-ink-tertiary">{soon}</span>
        </div>
      )}
    </div>
  );
}
