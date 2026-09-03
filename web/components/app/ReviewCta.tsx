"use client";

import Link from "next/link";

import { Float } from "@/components/app/Float";
import { useI18n } from "@/lib/i18n/client";

/**
 * Le bouton de révision.
 *
 * Dans la fiche, il flotte en bas à droite et brille : c'est le geste du cours
 * une fois le paquet écrit. Ailleurs, il reste une amorce de session posée dans
 * le flux - ce qu'on va faire, et pourquoi maintenant.
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
  if (floating) {
    return (
      <Float>
        <Link
          href={href as never}
          data-print="hide"
          className="fixed right-4 bottom-6 z-30 inline-flex h-9 items-center gap-2 rounded-lg border border-primary bg-primary px-3 text-sm font-medium text-primary-foreground shadow-xs lg:right-8"
        >
          {label}
        </Link>
      </Float>
    );
  }

  return (
    <Link
      href={href as never}
      className="flex min-w-[240px] items-center gap-3 rounded-2xl border border-border bg-card px-5 py-4"
    >
      <span className="min-w-0">
        <span className="block text-[15px] font-semibold leading-tight text-foreground">{label}</span>
        <span className="mt-0.5 block text-[13px] text-muted-foreground">{subtitle}</span>
      </span>
    </Link>
  );
}
