"use client";

import { useI18n } from "@/lib/i18n/client";

/**
 * La vignette de l'import : **les formats, en vrac et en l'air.**
 *
 * Une liste à puces aurait dit la même chose et n'aurait rien montré. Ce qu'il faut faire
 * comprendre en une seconde, c'est qu'on n'a rien à préparer : le polycopié scanné, la vidéo
 * du cours, les diapos du prof et l'enregistrement du TD entrent tels quels. Six pastilles
 * qui flottent à des rythmes différents disent « apporte ce que tu as » mieux qu'une phrase.
 *
 * Le mouvement est décoratif : `prefers-reduced-motion` l'arrête, et il n'emporte aucune
 * information avec lui.
 */
const FORMATS = [
  { key: "pdf", tone: "#d93025", label: "PDF", full: "PDF" },
  { key: "youtube", tone: "#ff0033", label: "YouTube", full: "YouTube" },
  { key: "word", tone: "#2b579a", label: "Word", full: "Word" },
  { key: "slides", tone: "#d24726", label: "PPT", full: "PowerPoint" },
  { key: "audio", tone: "#7c4dff", label: "Audio", full: "Audio" },
  { key: "photo", tone: "#0f9d58", label: "Photo", full: "Photo" },
] as const;

/** Position et cadence de chaque pastille. Rien d'aléatoire : la vignette doit être stable. */
const PLACES = [
  { left: "6%", top: "8%", delay: "0s", size: 64 },
  { left: "58%", top: "0%", delay: "1.1s", size: 56 },
  { left: "30%", top: "34%", delay: "0.5s", size: 72 },
  { left: "72%", top: "42%", delay: "1.7s", size: 60 },
  { left: "2%", top: "62%", delay: "2.2s", size: 56 },
  { left: "46%", top: "72%", delay: "0.8s", size: 52 },
] as const;

export function FormatsStory() {
  const { t } = useI18n();

  return (
    <div className="relative h-[260px] w-full max-w-[340px]">
      {FORMATS.map((format, index) => {
        const place = PLACES[index]!;
        return (
          <span
            key={format.key}
            className="float paper absolute flex flex-col items-center justify-center gap-1 rounded-[16px] bg-surface"
            style={{
              left: place.left,
              top: place.top,
              width: place.size,
              height: place.size,
              animationDelay: place.delay,
            }}
            title={format.full}
          >
            <span aria-hidden style={{ color: format.tone }}>
              <FormatIcon name={format.key} />
            </span>
            <span className="text-[8.5px] font-semibold uppercase tracking-wide text-ink-tertiary">
              {format.label}
            </span>
          </span>
        );
      })}
      <span className="sr-only">{t("onboarding.importerFormats")}</span>
    </div>
  );
}

function FormatIcon({ name }: { name: (typeof FORMATS)[number]["key"] }) {
  const size = "h-5 w-5";
  if (name === "pdf" || name === "word") {
    return (
      <svg viewBox="0 0 24 24" className={size}>
        <path
          d="M6 3.5h7L18.5 9v11.5h-12z"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.7"
          strokeLinejoin="round"
        />
        <path d="M13 3.5V9h5.5" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinejoin="round" />
      </svg>
    );
  }
  if (name === "youtube") {
    return (
      <svg viewBox="0 0 24 24" className={size}>
        <rect x="2.5" y="5.5" width="19" height="13" rx="4" fill="none" stroke="currentColor" strokeWidth="1.7" />
        <path d="M10.5 9.3l4.6 2.7-4.6 2.7z" fill="currentColor" />
      </svg>
    );
  }
  if (name === "slides") {
    return (
      <svg viewBox="0 0 24 24" className={size}>
        <rect x="3" y="4.5" width="18" height="12" rx="2" fill="none" stroke="currentColor" strokeWidth="1.7" />
        <path d="M12 16.5v3M8.5 19.5h7" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
      </svg>
    );
  }
  if (name === "audio") {
    return (
      <svg viewBox="0 0 24 24" className={size}>
        <rect x="9" y="2.8" width="6" height="11" rx="3" fill="none" stroke="currentColor" strokeWidth="1.7" />
        <path
          d="M5.5 11.5a6.5 6.5 0 0 0 13 0M12 18v3.2"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.7"
          strokeLinecap="round"
        />
      </svg>
    );
  }
  return (
    <svg viewBox="0 0 24 24" className={size}>
      <rect x="2.8" y="5.5" width="18.4" height="13.5" rx="3" fill="none" stroke="currentColor" strokeWidth="1.7" />
      <circle cx="12" cy="12.2" r="3.4" fill="none" stroke="currentColor" strokeWidth="1.7" />
      <path d="M8.5 5.5l1.2-2h4.6l1.2 2" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinejoin="round" />
    </svg>
  );
}
