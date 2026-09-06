"use client";

import Link from "next/link";

import { Float, useFloatDock } from "@/components/app/Float";
import { useI18n } from "@/lib/i18n/client";

/** Hauteur du bouton flottant (h-14) + 12 px d'écart pour la pastille d'offre. */
const FLOATING_CTA_DOCK = 68;

const shell =
  "flex w-full flex-col gap-4 rounded-2xl bg-accent px-6 py-5 text-left text-on-ink transition-[scale,background-color] duration-press ease-out-strong hover:bg-accent/90 active:scale-[0.96] sm:flex-row sm:items-center sm:gap-5";

/**
 * Le bouton de révision.
 *
 * Dans la fiche, c'est le même geste que « générer les cartes » : une carte
 * pleine largeur, puis un bouton ancré en bas pour le retrouver après le
 * défilement. Ailleurs, il reste une amorce de session posée dans le flux.
 */
export function ReviewCta({
  href,
  title,
  detail,
  floating = false,
}: {
  href: string;
  title?: string;
  detail?: string;
  floating?: boolean;
}) {
  const { t } = useI18n();
  const label = title ?? t("app.review.thisCourse");
  const subtitle = detail ?? t("app.review.ctaDetail");
  useFloatDock(floating ? FLOATING_CTA_DOCK : 0);
  if (floating) {
    return (
      <Float>
        <Link
          href={href as never}
          data-print="hide"
          className="pressable fixed right-4 bottom-6 z-30 inline-flex min-h-14 max-w-[calc(100%-2rem)] items-center gap-3 rounded-2xl bg-accent px-5 py-3.5 text-[16px] font-semibold leading-tight text-on-ink lg:right-8"
        >
          <span
            aria-hidden
            className="flex h-9 w-9 shrink-0 items-center justify-center rounded-tile bg-on-ink/10"
          >
            <ReviewGlyph />
          </span>
          {label}
        </Link>
      </Float>
    );
  }

  return (
    <Link href={href as never} className={shell} data-print="hide">
      <span className="flex min-w-0 flex-1 items-center gap-4">
        <span
          aria-hidden
          className="flex h-12 w-12 shrink-0 items-center justify-center rounded-tile bg-on-ink/10 sm:h-14 sm:w-14"
        >
          <ReviewGlyph />
        </span>
        <span className="min-w-0">
          <span className="block text-[18px] font-bold leading-tight">{label}</span>
          <span className="mt-1 block text-[14px] text-on-ink-muted">{subtitle}</span>
        </span>
      </span>
      <span className="inline-flex h-11 w-full shrink-0 items-center justify-center rounded-button bg-on-ink px-4 text-[15px] font-semibold text-ink sm:h-10 sm:w-auto">
        {t("copy.review")}
      </span>
    </Link>
  );
}

function ReviewGlyph() {
  return (
    <svg viewBox="0 0 24 24" className="h-6 w-6">
      <rect
        x="3.5"
        y="6.5"
        width="13"
        height="14"
        rx="2"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
      />
      <path
        d="M8 3.5h10.5A2 2 0 0 1 20.5 5.5V17"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
      />
    </svg>
  );
}
