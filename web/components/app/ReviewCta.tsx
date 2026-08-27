import Link from "next/link";

/**
 * Le bouton de révision.
 *
 * Dans la fiche, il flotte en bas à droite et brille : c'est le geste du cours
 * une fois le paquet écrit. Ailleurs, il reste une amorce de session posée dans
 * le flux — ce qu'on va faire, et pourquoi maintenant.
 */
export function ReviewCta({
  href,
  title = "Réviser ce cours",
  detail,
  floating = false,
}: {
  href: string;
  title?: string;
  detail?: string;
  floating?: boolean;
}) {
  if (floating) {
    return (
      <Link
        href={href as never}
        data-print="hide"
        className="pressable shiny fixed right-4 bottom-24 z-30 flex h-14 items-center gap-2.5 rounded-button bg-ink px-5 text-[15px] font-semibold text-on-ink shadow-floating lg:right-8 lg:bottom-8"
      >
        <span aria-hidden>⚡</span>
        {title}
      </Link>
    );
  }

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
