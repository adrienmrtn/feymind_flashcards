"use client";

import Link from "next/link";

import { Float, useFloatDock } from "@/components/app/Float";
import { buttonVariants } from "@/components/ui/button";
import { useI18n } from "@/lib/i18n/client";

/** Hauteur du bouton flottant (h-14) + 12 px d'écart pour la pastille d'offre. */
const FLOATING_CTA_DOCK = 68;

const shell =
  "panel group flex w-full flex-col gap-4 p-5 text-left transition-[border-color] duration-press ease-out-strong hover:border-stroke-strong sm:flex-row sm:items-center sm:gap-5";

/**
 * Le bouton de révision.
 *
 * Dans la fiche, c'est le même geste que « générer les cartes », et il prend donc la même
 * forme : un **panneau**, comme tout le reste de la page, avec l'action en vrai bouton
 * primaire à droite. Il était un pavé bleu pleine largeur à encre inversée, posé sous une
 * fiche qui ne parle qu'en surfaces claires cernées d'un trait ; deux pavés pleins l'un sous
 * l'autre - générer, puis réviser - donnaient une page qui crie deux fois.
 *
 * Le bouton flottant, lui, reste plein : il est posé **par-dessus** le texte, il n'a rien qui
 * le cerne, et un panneau clair qui flotte sur une fiche claire ne se verrait pas.
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
          className="flex h-11 w-11 shrink-0 items-center justify-center rounded-tile bg-surface-muted text-ink-secondary"
        >
          <ReviewGlyph />
        </span>
        <span className="min-w-0">
          <span className="section-title block">{label}</span>
          <span className="section-lead block max-w-[46ch]">{subtitle}</span>
        </span>
      </span>
      <span
        aria-hidden
        className={buttonVariants({
          className: "w-full shrink-0 group-active:scale-[0.96] sm:w-auto",
          size: "lg",
        })}
      >
        {t("copy.review")}
      </span>
    </Link>
  );
}

function ReviewGlyph() {
  return (
    <svg viewBox="0 0 24 24" className="h-5 w-5">
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
