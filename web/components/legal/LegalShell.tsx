"use client";

import { Footer } from "@/components/landing/Footer";
import { SiteHeader } from "@/components/site/SiteHeader";
import { useI18n } from "@/lib/i18n/client";
import { localizedHref } from "@/lib/i18n/paths";
import { SITE_PAGES, siteNavKey } from "@/lib/site-pages";

/**
 * Une page de droit, sur le même papier que le reste.
 *
 * La même barre que partout ailleurs, et le texte dans une carte blanche à largeur de
 * lecture : on vient lire, et un texte de droit posé à même le fond gris se lit comme un
 * document oublié. Le pied de page reste, pour passer de l'une à l'autre. La langue se
 * change dans la barre, parce que l'iPhone ouvre ces adresses hors de la vitrine.
 */
export function LegalShell({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  const { t, locale } = useI18n();
  const nav = SITE_PAGES.map((page) => ({
    href: localizedHref(locale, page.path),
    label: t(siteNavKey(page.id)),
  }));

  return (
    <>
      <SiteHeader nav={nav} ariaLabel={t("articles.shared.navAria")} />

      <main id="contenu" className="mx-auto w-full max-w-page px-screen pt-10 sm:pt-14">
        <article className="paper mx-auto max-w-[820px] rounded-sheet bg-surface px-6 py-10 sm:px-14 sm:py-14">
          <p className="eyebrow text-ink-tertiary">{t("legal.eyebrow")}</p>
          <h1 className="mt-3 text-balance text-[32px] font-bold leading-[1.08] tracking-tight-title text-ink sm:text-[40px]">
            {title}
          </h1>
          <p className="mt-3 text-[13.5px] text-ink-tertiary">
            {t("legal.updated", { date: t("legal.updatedDate") })}
          </p>
          <div className="legal-prose mt-10 max-w-reading">{children}</div>
        </article>
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
