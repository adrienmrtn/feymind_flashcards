import type { ReactNode } from "react";
import Link from "next/link";

import { Footer } from "@/components/landing/Footer";
import { StartButton } from "@/components/landing/StartButton";
import { SiteHeader } from "@/components/site/SiteHeader";
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
 * **La coquille des pages de fond.**
 *
 * Elle porte la même barre que la vitrine, avec les autres pages en guise de liens : ici on
 * navigue entre pages, ce que Google explore. Le titre est centré, comme ceux du parcours et
 * de la vitrine : une page de fond n'est pas un article de blog, c'est une page du produit
 * qui explique une chose, et elle se présente comme telle.
 *
 * `figure` pose sous le chapeau une vraie partie du produit : la vignette du parcours qui
 * montre ce dont la page parle. Une page qui explique la méthode sans montrer les quatre
 * boutons parle dans le vide.
 *
 * Titres, extraits et appels à l'action viennent des catalogues. Une langue
 * figée ici remettrait le français dans l'index dès que le robot passe.
 *
 * La coquille ne lit pas la session : une page de fond doit rester statique et se mettre
 * en cache, et le bouton dit « Commencer » à tout le monde. Une session ouverte retombe de
 * toute façon sur l'app depuis le parcours.
 */
export async function ArticleShell({
  page,
  eyebrow,
  title,
  lead,
  figure,
  children,
}: {
  page: SitePage;
  eyebrow: string;
  title: string;
  lead: ReactNode;
  figure?: ReactNode;
  children: ReactNode;
}) {
  const { t, locale } = await getTranslator();
  const nav = SITE_PAGES.map((item) => ({
    href: localizedHref(locale, item.path),
    label: t(siteNavKey(item.id)),
    current: item.path === page.path,
  }));

  return (
    <>
      <SiteHeader nav={nav} ariaLabel={t("articles.shared.navAria")} />

      <main id="contenu" className="mx-auto w-full max-w-page px-screen pb-4 pt-14 sm:pt-20">
        <header className="mx-auto max-w-[62ch] text-center">
          <p className="eyebrow text-ink-tertiary">{eyebrow}</p>
          <h1 className="mt-3 text-balance text-[34px] font-bold leading-[1.06] tracking-tight-title text-ink sm:text-[48px]">
            {title}
          </h1>
          <div className="mx-auto mt-6 max-w-reading space-y-4 text-left text-[16.5px] leading-relaxed text-ink-secondary sm:text-center">
            {lead}
          </div>
        </header>

        {figure ? (
          <div className="paper mx-auto mt-12 max-w-[860px] rounded-sheet bg-surface p-4 sm:p-6">
            <div className="flex min-h-[300px] items-center justify-center rounded-[22px] bg-surface-muted p-6 sm:p-8">
              {figure}
            </div>
          </div>
        ) : null}

        <div className="mx-auto mt-6 max-w-[860px]">{children}</div>

        <NextToRead current={page} />

        <section className="paper mx-auto mt-20 max-w-[860px] rounded-sheet bg-surface px-6 py-12 text-center sm:px-12">
          <h2 className="mx-auto max-w-[26ch] text-balance text-[26px] font-bold leading-tight tracking-tight-title text-ink sm:text-[34px]">
            {t("articles.shared.ctaTitle")}
          </h2>
          <p className="mx-auto mt-3 max-w-[48ch] text-[15px] leading-relaxed text-ink-secondary">
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

/** Une section de page : un titre qu'on peut lier, et du texte à la largeur de lecture. */
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
      <h2 className="mx-auto max-w-reading text-[24px] font-bold leading-tight tracking-tight-title text-ink sm:text-[30px]">
        {title}
      </h2>
      <div
        className={`mt-4 space-y-4 text-[16px] leading-relaxed text-ink-secondary ${
          wide ? "" : "mx-auto max-w-reading"
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
    <aside className="mx-auto mt-8 max-w-reading rounded-group border-l-2 border-accent bg-accent-soft/45 px-5 py-4 text-[15px] leading-relaxed text-ink-secondary">
      {children}
    </aside>
  );
}

/**
 * Une vraie partie du produit posée au milieu d'une page : la vignette dans un cadre gris,
 * la légende à côté. C'est la forme des écrans de démonstration du parcours, reprise telle
 * quelle pour que les pages de fond montrent ce qu'elles expliquent.
 */
export function ArticleFigure({
  children,
  caption,
}: {
  children: ReactNode;
  caption?: ReactNode;
}) {
  return (
    <figure className="paper mt-8 grid items-center gap-6 overflow-hidden rounded-sheet bg-surface p-4 sm:p-6 lg:grid-cols-[minmax(0,1fr)_minmax(0,32ch)] lg:gap-10">
      <div className="flex min-h-[260px] items-center justify-center rounded-[22px] bg-surface-muted p-6 sm:p-8">
        {children}
      </div>
      {caption ? (
        <figcaption className="text-[15px] leading-relaxed text-ink-secondary lg:pr-4">{caption}</figcaption>
      ) : null}
    </figure>
  );
}

async function NextToRead({ current }: { current: SitePage }) {
  const { t, locale } = await getTranslator();
  const rest = otherPages(current);

  return (
    <section className="mx-auto mt-24 max-w-[860px] border-t border-hairline-on-canvas pt-10">
      <h2 className="eyebrow text-ink-tertiary">{t("articles.shared.nextTitle")}</h2>
      <ul className="mt-5 grid gap-4 sm:grid-cols-2">
        {rest.map((page) => (
          <li key={page.path}>
            <Link
              href={localizedHref(locale, page.path)}
              className="paper lift block h-full rounded-group bg-surface p-5"
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
