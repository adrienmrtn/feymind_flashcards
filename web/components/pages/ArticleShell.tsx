import Link from "next/link";

import { BrandLockup } from "@/components/BrandMark";
import { Footer } from "@/components/landing/Footer";
import { StartButton } from "@/components/landing/StartButton";
import { CANONICAL_URL, IS_INDEXABLE } from "@/lib/config";
import { SITE_PAGES, otherPages, type SitePage } from "@/lib/site-pages";

/**
 * **La coquille des pages de contenu.**
 *
 * Elle n'emprunte pas la barre de la vitrine, et ce n'est pas une question de goût : cette
 * barre navigue par ancres (`#methode`), et une ancre pointe **dans la page courante**. Posée
 * ici, elle donnerait quatre liens qui ne font rien. La barre de ces pages mène donc aux
 * autres pages, ce qui est aussi ce qu'on veut : trois pages qui se citent l'une l'autre
 * sont trois pages que Google explore, au lieu d'une seule qu'il atteint depuis le pied.
 *
 * Chaque page se termine sur les deux autres puis sur une seule action. Un article qui
 * s'arrête sur rien renvoie au bouton précédent, c'est-à-dire à la page de résultats.
 */
export function ArticleShell({
  page,
  eyebrow,
  title,
  lead,
  children,
}: {
  page: SitePage;
  eyebrow: string;
  /** Le `h1`. Il peut différer du titre de l'onglet : celui-ci se lit à l'écran. */
  title: string;
  lead: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <>
      <header className="sticky top-0 z-20 border-b border-border/80 bg-background/70 backdrop-blur-md">
        <a
          href="#contenu"
          className="sr-only focus-visible:not-sr-only focus-visible:absolute focus-visible:left-screen focus-visible:top-3 focus-visible:z-30 focus-visible:rounded-button focus-visible:bg-accent focus-visible:px-3 focus-visible:py-2 focus-visible:text-[13px] focus-visible:font-medium focus-visible:text-on-ink"
        >
          Aller au contenu
        </a>
        <div className="mx-auto flex h-14 max-w-page items-center justify-between gap-6 px-screen">
          <BrandLockup
            href="/"
            size={28}
            className="shrink-0 text-foreground"
            wordClassName="text-[15px] font-bold tracking-tight text-foreground"
          />

          <nav aria-label="Pages" className="hidden items-center gap-7 md:flex">
            {SITE_PAGES.map((item) => {
              const current = item.path === page.path;
              return (
                <Link
                  key={item.path}
                  href={item.path}
                  aria-current={current ? "page" : undefined}
                  className={
                    current
                      ? "text-[13.5px] font-semibold text-ink"
                      : "underline-draw text-[13.5px] font-medium text-ink-secondary"
                  }
                >
                  {item.label}
                </Link>
              );
            })}
          </nav>

          <StartButton size="compact" />
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
            Dépose un cours, regarde ce qu&apos;il devient.
          </h2>
          <p className="mt-3 text-[15px] leading-relaxed text-ink-secondary">
            Le premier est gratuit, sur le site comme sur iPhone.
          </p>
          <div className="mt-8 flex justify-center">
            <StartButton />
          </div>
        </section>
      </main>

      <Footer />
      <ArticleStructuredData page={page} />
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
  children: React.ReactNode;
  /** Vrai pour une section qui porte un graphe : il déborde la colonne de texte. */
  wide?: boolean;
}) {
  return (
    // `scroll-mt` : la barre est collante, et une ancre sans marge dépose son titre derrière.
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
export function ArticleNote({ children }: { children: React.ReactNode }) {
  return (
    <aside className="mt-8 max-w-reading rounded-group border-l-2 border-accent bg-accent-soft/45 px-5 py-4 text-[15px] leading-relaxed text-ink-secondary">
      {children}
    </aside>
  );
}

function NextToRead({ current }: { current: SitePage }) {
  const rest = otherPages(current);

  return (
    <section className="mt-24 border-t border-hairline-on-canvas pt-10">
      <h2 className="eyebrow text-ink-tertiary">À lire ensuite</h2>
      <ul className="mt-5 grid gap-4 sm:grid-cols-2">
        {rest.map((page) => (
          <li key={page.path}>
            <Link
              href={page.path}
              className="lift block h-full rounded-group border border-stroke bg-surface p-5 transition-[border-color] duration-hover ease-out-strong hover:border-stroke-strong"
            >
              <p className="text-[16px] font-semibold tracking-tight text-ink">{page.label}</p>
              <p className="mt-1.5 text-[14px] leading-relaxed text-ink-secondary">
                {page.description}
              </p>
            </Link>
          </li>
        ))}
      </ul>
    </section>
  );
}

/**
 * **Le fil d'Ariane, et la page comme entité.**
 *
 * `BreadcrumbList` est l'une des rares données structurées que Google affiche encore
 * réellement : elle remplace l'adresse verte sous le titre par « Micabo › La méthode ». Elle
 * ne fabrique pas de sitelinks — ceux-là se gagnent en ayant des pages explorées et liées
 * entre elles, ce que fait la barre ci-dessus.
 *
 * Pas de `FAQPage` : depuis 2023, Google ne l'affiche plus que pour les sites d'autorité
 * publique ou de santé. La déclarer ici ne coûterait rien et ne donnerait rien, ce qui en
 * fait exactement le genre de balise qu'on ajoute « au cas où » et qu'on ne retire jamais.
 */
function ArticleStructuredData({ page }: { page: SitePage }) {
  if (!IS_INDEXABLE) return null;

  const url = `${CANONICAL_URL}${page.path}`;
  const graph = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebPage",
        "@id": `${url}#page`,
        url,
        name: page.title,
        description: page.description,
        inLanguage: "fr-FR",
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
            item: `${CANONICAL_URL}/`,
          },
          {
            "@type": "ListItem",
            position: 2,
            name: page.label,
            item: url,
          },
        ],
      },
    ],
  };

  return (
    <script
      type="application/ld+json"
      // Rien ici ne vient d'un utilisateur. Les chevrons sont neutralisés par prudence : un
      // `</script>` dans une chaîne refermerait la balise.
      dangerouslySetInnerHTML={{ __html: JSON.stringify(graph).replace(/</g, "\\u003c") }}
    />
  );
}
