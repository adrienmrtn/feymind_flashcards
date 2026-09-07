import type { ReactNode } from "react";
import Link from "next/link";

import { AppearanceSwitcher } from "@/components/appearance/AppearanceSwitcher";
import { BrandLockup } from "@/components/BrandMark";
import { LanguageSwitcher } from "@/components/i18n/LanguageSwitcher";
import { Footer } from "@/components/landing/Footer";
import { StartButton } from "@/components/landing/StartButton";
import { CANONICAL_URL, IS_INDEXABLE } from "@/lib/config";
import { localizedHref, localizedPath } from "@/lib/i18n/paths";
import { getTranslator } from "@/lib/i18n/server";
import { UI_LOCALE_META } from "@/lib/i18n/locales";
import {
  SITE_PAGES,
  articleMetaDescriptionKey,
  articleMetaTitleKey,
  otherPages,
  siteNavKey,
  type SitePage,
} from "@/lib/site-pages";

/**
 * **La coquille des pages de contenu.**
 *
 * Elle n'emprunte pas la barre de la vitrine : cette barre navigue par ancres
 * (`#methode`), et une ancre pointe dans la page courante. Ici la barre mène
 * aux autres pages, ce que Google explore.
 *
 * Titres, extraits et appels à l'action viennent des catalogues. Une langue
 * figée ici remettrait le français dans l'index dès que le robot passe.
 */
export async function ArticleShell({
  page,
  eyebrow,
  title,
  lead,
  children,
}: {
  page: SitePage;
  eyebrow: string;
  title: string;
  lead: ReactNode;
  children: ReactNode;
}) {
  const { t, locale } = await getTranslator();

  return (
    <>
      <header className="sticky top-0 z-20 border-b border-border/80 bg-background/70 backdrop-blur-md">
        <a
          href="#contenu"
          className="sr-only focus-visible:not-sr-only focus-visible:absolute focus-visible:left-screen focus-visible:top-3 focus-visible:z-30 focus-visible:rounded-button focus-visible:bg-accent focus-visible:px-3 focus-visible:py-2 focus-visible:text-[13px] focus-visible:font-medium focus-visible:text-on-ink"
        >
          {t("common.skipToContent")}
        </a>
        <div className="mx-auto flex h-14 max-w-page items-center justify-between gap-6 px-screen">
          <BrandLockup
            href={localizedHref(locale, "/")}
            size={28}
            className="shrink-0 text-foreground"
            wordClassName="text-[15px] font-bold tracking-tight text-foreground"
          />

          <nav aria-label={t("articles.shared.navAria")} className="hidden items-center gap-7 md:flex">
            {SITE_PAGES.map((item) => {
              const current = item.path === page.path;
              return (
                <Link
                  key={item.path}
                  href={localizedHref(locale, item.path)}
                  aria-current={current ? "page" : undefined}
                  className={
                    current
                      ? "text-[13.5px] font-semibold text-ink"
                      : "underline-draw text-[13.5px] font-medium text-ink-secondary"
                  }
                >
                  {t(siteNavKey(item.id))}
                </Link>
              );
            })}
          </nav>

          <div className="flex min-w-0 shrink-0 items-center gap-1 sm:gap-2">
            <AppearanceSwitcher variant="compact" />
            <LanguageSwitcher />
            <StartButton size="compact" />
          </div>
        </div>
      </header>

      <main id="contenu" className="mx-auto w-full max-w-page px-screen pb-4 pt-12 sm:pt-16">
        <div className="max-w-reading">
          <p className="eyebrow text-ink-tertiary">{eyebrow}</p>
          <h1 className="mt-3 text-[32px] font-bold leading-[1.06] tracking-tight-title text-ink sm:text-[44px]">
            {title}
          </h1>
          <div className="mt-5 space-y-4 text-[16.5px] leading-relaxed text-ink-secondary">
            {lead}
          </div>
        </div>

        {children}

        <NextToRead current={page} />

        <section className="mx-auto mt-24 max-w-reading text-center">
          <h2 className="text-[26px] font-bold leading-tight tracking-tight-title text-ink sm:text-[32px]">
            {t("articles.shared.ctaTitle")}
          </h2>
          <p className="mt-3 text-[15px] leading-relaxed text-ink-secondary">
            {t("articles.shared.ctaBody")}
          </p>
          <div className="mt-8 flex justify-center">
            <StartButton />
          </div>
        </section>
      </main>

      <Footer />
      <ArticleStructuredData
        page={page}
        locale={locale}
        title={t(articleMetaTitleKey(page.id))}
        description={t(articleMetaDescriptionKey(page.id))}
        label={t(siteNavKey(page.id))}
      />
    </>
  );
}

/** Une section d'article : un titre qu'on peut lier, et du texte à la largeur de lecture. */
export function ArticleSection({
  id,
  title,
  children,
  wide = false,
}: {
  id: string;
  title: string;
  children: ReactNode;
  wide?: boolean;
}) {
  return (
    <section id={id} className="mt-16 scroll-mt-20">
      <h2 className="max-w-reading text-[24px] font-bold leading-tight tracking-tight-title text-ink sm:text-[30px]">
        {title}
      </h2>
      <div
        className={`mt-4 space-y-4 text-[16px] leading-relaxed text-ink-secondary ${
          wide ? "" : "max-w-reading"
        }`}
      >
        {children}
      </div>
    </section>
  );
}

/** Un aparté : ce qu'il faut savoir avant d'en attendre trop. */
export function ArticleNote({ children }: { children: ReactNode }) {
  return (
    <aside className="mt-8 max-w-reading rounded-group border-l-2 border-accent bg-accent-soft/45 px-5 py-4 text-[15px] leading-relaxed text-ink-secondary">
      {children}
    </aside>
  );
}

async function NextToRead({ current }: { current: SitePage }) {
  const { t, locale } = await getTranslator();
  const rest = otherPages(current);

  return (
    <section className="mt-24 border-t border-hairline-on-canvas pt-10">
      <h2 className="eyebrow text-ink-tertiary">{t("articles.shared.nextTitle")}</h2>
      <ul className="mt-5 grid gap-4 sm:grid-cols-2">
        {rest.map((page) => (
          <li key={page.path}>
            <Link
              href={localizedHref(locale, page.path)}
              className="lift block h-full rounded-group border border-stroke bg-surface p-5 transition-[border-color] duration-hover ease-out-strong hover:border-stroke-strong"
            >
              <p className="text-[16px] font-semibold tracking-tight text-ink">
                {t(siteNavKey(page.id))}
              </p>
              <p className="mt-1.5 text-[14px] leading-relaxed text-ink-secondary">
                {t(articleMetaDescriptionKey(page.id))}
              </p>
            </Link>
          </li>
        ))}
      </ul>
    </section>
  );
}

/**
 * `BreadcrumbList` remplace l'adresse verte sous le titre par « Micabo › La
 * méthode ». `inLanguage` suit la locale servie : un robot qui lit le turc
 * ne doit pas trouver `fr-FR` dans le graphe.
 */
function ArticleStructuredData({
  page,
  locale,
  title,
  description,
  label,
}: {
  page: SitePage;
  locale: keyof typeof UI_LOCALE_META;
  title: string;
  description: string;
  label: string;
}) {
  if (!IS_INDEXABLE) return null;

  const path = localizedPath(locale, page.path);
  const url = path === "/" ? `${CANONICAL_URL}/` : `${CANONICAL_URL}${path}`;
  const home = localizedPath(locale, "/") === "/" ? `${CANONICAL_URL}/` : `${CANONICAL_URL}${localizedPath(locale, "/")}`;
  const graph = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebPage",
        "@id": `${url}#page`,
        url,
        name: title,
        description,
        inLanguage: UI_LOCALE_META[locale].bcp47,
        isPartOf: { "@id": `${CANONICAL_URL}/#website` },
        publisher: { "@id": `${CANONICAL_URL}/#organization` },
        breadcrumb: { "@id": `${url}#breadcrumb` },
      },
      {
        "@type": "BreadcrumbList",
        "@id": `${url}#breadcrumb`,
        itemListElement: [
          {
            "@type": "ListItem",
            position: 1,
            name: "Micabo",
            item: home,
          },
          {
            "@type": "ListItem",
            position: 2,
            name: label,
            item: url,
          },
        ],
      },
    ],
  };

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(graph).replace(/</g, "\\u003c") }}
    />
  );
}
