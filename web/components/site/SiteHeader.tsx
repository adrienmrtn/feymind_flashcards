"use client";

import type { Route } from "next";
import Link from "next/link";

import { AppearanceSwitcher } from "@/components/appearance/AppearanceSwitcher";
import { BrandLockup } from "@/components/BrandMark";
import { LanguageSwitcher } from "@/components/i18n/LanguageSwitcher";
import { StartButton } from "@/components/landing/StartButton";
import { useI18n } from "@/lib/i18n/client";
import { useLocalizedHref } from "@/lib/i18n/href";

export interface SiteNavItem {
  href: string;
  label: string;
  current?: boolean;
}

/**
 * **La barre de toutes les pages publiques.**
 *
 * La vitrine, les pages de fond et les pages de droit portaient chacune leur barre, presque
 * la même à un détail près. Une seule barre, avec les liens qu'on lui donne : des ancres sur
 * la vitrine, des pages ailleurs. Elle ne ressemble pas à la jauge du parcours d'inscription,
 * pour que le site ne se lise pas comme un tunnel.
 *
 * Les liens sont masqués sur mobile : quatre libellés et un bouton ne tiennent pas sur
 * 360 px, et le pied de page les reprend.
 */
export function SiteHeader({
  nav,
  signedIn = false,
  ariaLabel,
}: {
  nav: readonly SiteNavItem[];
  signedIn?: boolean;
  ariaLabel?: string;
}) {
  const { t } = useI18n();
  const homeHref = useLocalizedHref("/");

  return (
    <header className="sticky top-0 z-20 border-b border-hairline-on-canvas bg-canvas/80 backdrop-blur-md">
      <a
        href="#contenu"
        className="sr-only focus-visible:not-sr-only focus-visible:absolute focus-visible:left-screen focus-visible:top-3 focus-visible:z-30 focus-visible:rounded-button focus-visible:bg-accent focus-visible:px-3 focus-visible:py-2 focus-visible:text-[13px] focus-visible:font-medium focus-visible:text-on-ink"
      >
        {t("common.skipToContent")}
      </a>
      <div className="mx-auto flex h-14 max-w-page items-center justify-between gap-3 px-screen sm:gap-6">
        <BrandLockup
          href={homeHref}
          size={28}
          className="shrink-0 text-ink"
          wordClassName="text-[15px] font-bold tracking-tight text-ink"
        />

        <nav aria-label={ariaLabel ?? t("landing.navAria")} className="hidden items-center gap-6 md:flex">
          {nav.map((item) =>
            item.href.startsWith("#") ? (
              <a
                key={item.href}
                href={item.href}
                className="underline-draw whitespace-nowrap text-[13.5px] font-medium text-ink-secondary"
              >
                {item.label}
              </a>
            ) : (
              <Link
                key={item.href}
                href={item.href as Route}
                aria-current={item.current ? "page" : undefined}
                className={
                  item.current
                    ? "whitespace-nowrap text-[13.5px] font-semibold text-ink"
                    : "underline-draw whitespace-nowrap text-[13.5px] font-medium text-ink-secondary"
                }
              >
                {item.label}
              </Link>
            ),
          )}
        </nav>

        <div className="flex min-w-0 items-center justify-end gap-1 sm:gap-2">
          <div className="hidden shrink-0 sm:block">
            <AppearanceSwitcher variant="compact" />
          </div>
          <LanguageSwitcher />
          <StartButton signedIn={signedIn} size="compact" />
        </div>
      </div>
    </header>
  );
}
