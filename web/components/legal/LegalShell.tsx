"use client";

import Link from "next/link";

import { BrandLockup } from "@/components/BrandMark";
import { LanguageSwitcher } from "@/components/i18n/LanguageSwitcher";
import { Footer } from "@/components/landing/Footer";
import { useI18n } from "@/lib/i18n/client";

/**
 * Une page de droit, sur le même papier que le reste.
 *
 * Pas la barre marketing : on vient lire, pas commencer. La langue se
 * change ici, parce que l'iPhone ouvre ces adresses hors de la vitrine.
 * Le pied de page reste, pour passer de l'une à l'autre.
 */
export function LegalShell({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  const { t } = useI18n();

  return (
    <>
      <a
        href="#contenu"
        className="sr-only focus-visible:not-sr-only focus-visible:absolute focus-visible:left-screen focus-visible:top-3 focus-visible:z-30 focus-visible:rounded-button focus-visible:bg-accent focus-visible:px-3 focus-visible:py-2 focus-visible:text-[13px] focus-visible:font-medium focus-visible:text-on-ink"
      >
        {t("common.skipToContent")}
      </a>
      <header className="border-b border-hairline-on-canvas">
        <div className="mx-auto flex h-14 max-w-page items-center justify-between gap-3 px-screen">
          <BrandLockup
            href="/"
            size={28}
            className="text-ink"
            wordClassName="text-[15px] font-bold tracking-tight text-ink"
          />
          <div className="flex min-w-0 items-center gap-2 sm:gap-3">
            <LanguageSwitcher />
            <Link
              href="/"
              className="underline-draw shrink-0 text-[13.5px] text-ink-secondary"
            >
              {t("legal.backHome")}
            </Link>
          </div>
        </div>
      </header>

      <main id="contenu" className="mx-auto w-full max-w-reading px-screen py-12 sm:py-16">
        <p className="eyebrow text-ink-tertiary">{t("legal.eyebrow")}</p>
        <h1 className="mt-3 text-[32px] font-bold leading-[1.08] tracking-tight-title text-ink sm:text-[40px]">
          {title}
        </h1>
        <p className="mt-3 text-[13.5px] text-ink-tertiary">
          {t("legal.updated", { date: t("legal.updatedDate") })}
        </p>
        <div className="legal-prose mt-10">{children}</div>
      </main>

      <Footer />
    </>
  );
}

export function LegalSection({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="mt-9">
      <h2 className="text-[18px] font-semibold tracking-tight text-ink">{title}</h2>
      <div className="mt-3 space-y-3 text-[15px] leading-relaxed text-ink-secondary">{children}</div>
    </section>
  );
}
