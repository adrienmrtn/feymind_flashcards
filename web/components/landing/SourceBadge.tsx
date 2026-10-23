/**
 * **La pastille d'un support** : PDF, Word, photo, YouTube, audio, texte.
 *
 * Dessinée ici plutôt que prise aux icônes 3D : la carte du héros et la bande des formats
 * alignent six pastilles côte à côte, et six objets de la même famille se lisent comme une
 * liste, là où des volumes 3D de tailles différentes se lisent comme un tas. Chaque pastille
 * prend un ton de leçon (pâle pour le fond, encre pour le dessin), donc elle suit la nuit.
 */
export type SourceKind = "pdf" | "word" | "photo" | "youtube" | "audio" | "text";

const TONE: Record<SourceKind, string> = {
  pdf: "pink",
  word: "blue",
  photo: "yellow",
  youtube: "pink",
  audio: "mint",
  text: "lilac",
};

export function SourceBadge({ kind, size = 36 }: { kind: SourceKind; size?: number }) {
  const tone = TONE[kind];
  const youtube = kind === "youtube";
  return (
    <span
      aria-hidden
      className="relative inline-flex shrink-0 items-center justify-center"
      style={{
        width: size,
        height: size,
        borderRadius: Math.round(size * 0.3),
        background: youtube ? "#ff1f3d" : `var(--color-tone-${tone}-pale)`,
        color: youtube ? "#ffffff" : `var(--color-tone-${tone}-ink)`,
      }}
    >
      <Glyph kind={kind} size={size} />
    </span>
  );
}

function Glyph({ kind, size }: { kind: SourceKind; size: number }) {
  const label = Math.max(8, Math.round(size * 0.26));
  switch (kind) {
    case "pdf":
      return (
        <span className="font-extrabold leading-none tracking-[-0.02em]" style={{ fontSize: label }}>
          PDF
        </span>
      );
    case "word":
      return (
        <span className="font-extrabold leading-none tracking-[-0.02em]" style={{ fontSize: label }}>
          DOC
        </span>
      );
    case "photo":
      return (
        <svg viewBox="0 0 24 24" width={size * 0.56} height={size * 0.56} fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
          <rect x="3" y="4.5" width="18" height="15" rx="3.5" />
          <circle cx="9" cy="10" r="1.8" fill="currentColor" stroke="none" />
          <path d="m4.5 17.5 5-5 3.5 3.5 2.5-2.5 4 4" />
        </svg>
      );
    case "youtube":
      return (
        <svg viewBox="0 0 24 24" width={size * 0.46} height={size * 0.46} fill="currentColor">
          <path d="M8 5.6v12.8a1 1 0 0 0 1.52.85l10.2-6.4a1 1 0 0 0 0-1.7L9.52 4.75A1 1 0 0 0 8 5.6Z" />
        </svg>
      );
    case "audio":
      return (
        <svg viewBox="0 0 24 24" width={size * 0.56} height={size * 0.56} fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round">
          <path d="M4 10v4M8 7v10M12 4v16M16 8v8M20 10.5v3" />
        </svg>
      );
    case "text":
      return (
        <svg viewBox="0 0 24 24" width={size * 0.56} height={size * 0.56} fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round">
          <path d="M5 6h14M12 6v13M8.5 19h7" />
        </svg>
      );
  }
}
