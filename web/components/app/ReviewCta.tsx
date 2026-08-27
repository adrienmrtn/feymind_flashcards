import Link from "next/link";

/**
 * Le bouton de révision : pas un simple bloc d'encre « Réviser ce cours ».
 * Une vraie amorce de session — ce qu'on va faire, et pourquoi maintenant.
 */
export function ReviewCta({
  href,
  title = "Réviser ce cours",
  detail,
}: {
  href: string;
  title?: string;
  detail?: string;
}) {
  return (
    <Link
      href={href as never}
      className="pressable flex min-w-[240px] items-center gap-3.5 rounded-group bg-ink px-5 py-4 text-on-ink"
    >
      <span
        aria-hidden
        className="flex h-11 w-11 shrink-0 items-center justify-center rounded-tile bg-white/10 text-[22px]"
      >
        ⚡
      </span>
      <span className="min-w-0">
        <span className="block text-[16px] font-bold leading-tight">{title}</span>
        <span className="mt-0.5 block text-[13px] text-on-ink-muted">
          {detail ?? "Les cartes dues, maintenant."}
        </span>
      </span>
    </Link>
  );
}
