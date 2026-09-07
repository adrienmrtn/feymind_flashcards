import type { Metadata, Viewport } from "next";
import { Hanken_Grotesk, Inter, Nunito } from "next/font/google";

import { Analytics } from "@vercel/analytics/next";

import { AppearanceProvider } from "@/components/appearance/AppearanceProvider";
import { AuthReturnCatcher } from "@/components/landing/AuthReturnCatcher";
import { PreviewBanner } from "@/components/PreviewBanner";
import {
  APPEARANCE_BOOT_SCRIPT,
  APPEARANCE_THEME_COLOR,
  appearanceIsDark,
} from "@/lib/appearance";
import { readAppearance } from "@/lib/appearance-server";
import { I18nProvider } from "@/lib/i18n/client";
import { catalogFor } from "@/lib/i18n/catalogs";
import { UI_LOCALE_META } from "@/lib/i18n/locales";
import { getTranslator, readUiLocale } from "@/lib/i18n/server";
import type { MessageTree } from "@/lib/i18n/format";
import { CANONICAL_URL, IS_INDEXABLE, SITE_URL } from "@/lib/config";
import { SiteStructuredData } from "@/components/landing/StructuredData";

import "./globals.css";

/**
 * Hanken Grotesk écrit les mots. C'est la police embarquée de l'app
 * (`Micabo/Resources/Fonts/`), reprise ici depuis Google Fonts en variable : `next/font`
 * l'héberge lui-même au moment de la compilation, donc aucun appel à un tiers à l'exécution.
 */
const hanken = Hanken_Grotesk({
  subsets: ["latin", "latin-ext"],
  weight: ["400", "500", "600", "700"],
  variable: "--font-hanken",
  display: "swap",
});

/**
 * Nunito écrit **les nombres**, et seulement eux.
 *
 * SF Rounded n'existe pas sur le web, et « un grand nombre en arrondi ressemble à un score »
 * est un choix d'intention de l'app, pas un détail de goût. Nunito est la plus proche des
 * arrondies libres. Le reproche qu'on peut lui faire est d'être partout : il ne porte pas ici,
 * parce qu'elle ne compose jamais un mot - une police qu'on ne voit que sur des chiffres ne se
 * reconnaît pas.
 */
const nunito = Nunito({
  subsets: ["latin", "latin-ext"],
  weight: ["600", "700", "800"],
  variable: "--font-nunito",
  display: "swap",
});

/** Inter porte l'app connectée — le même corps que micabo OS. */
const inter = Inter({
  subsets: ["latin", "latin-ext"],
  variable: "--font-inter",
  display: "swap",
});

/**
 * Ce que Micabo dit de lui-même dans un résultat de recherche.
 *
 * `title.template` évite le titre le plus courant du web : la même phrase sur douze pages.
 * Google réécrit un titre qu'il juge dupliqué, et il le réécrit mal. Chaque page pose son
 * `title` court, la marque est ajoutée ici.
 *
 * `metadataBase` est l'hôte **canonique**, pas celui qui sert la requête : sans lui, les
 * images de partage et les balises canoniques d'une prévisualisation pointeraient vers une
 * adresse qui meurt au déploiement suivant.
 */
export async function generateMetadata(): Promise<Metadata> {
  const { t, locale } = await getTranslator();
  const title = t("landing.siteTitle");
  const description = t("landing.metaDescription");
  return {
    metadataBase: new URL(IS_INDEXABLE ? CANONICAL_URL : SITE_URL),
    title: {
      default: title,
      template: "%s - Micabo",
    },
    description,
    applicationName: "micabo",
    alternates: { canonical: "/" },
    robots: IS_INDEXABLE ? undefined : { index: false, follow: false },
    icons: {
      icon: [
        { url: "/icon-48.png", type: "image/png", sizes: "48x48" },
        { url: "/icon-192.png", type: "image/png", sizes: "192x192" },
        { url: "/icon.svg", type: "image/svg+xml" },
        { url: "/icon-32.png", type: "image/png", sizes: "32x32" },
        { url: "/favicon.ico", sizes: "32x32" },
      ],
      apple: [{ url: "/apple-touch-icon.png", sizes: "180x180" }],
    },
    manifest: "/manifest.webmanifest",
    openGraph: {
      type: "website",
      siteName: "micabo",
      locale: UI_LOCALE_META[locale].og,
      url: "/",
      title,
      description: t("landing.ogDescription"),
    },
    twitter: {
      card: "summary_large_image",
      title,
      description: t("landing.ogDescriptionShort"),
    },
  };
}

export const viewport: Viewport = {
  // La couleur de la barre du navigateur suit le papier : une bande blanche au-dessus d'un fond
  // teinté fait lire une bordure là où il n'y en a pas. Nuit et crépuscule la remplacent
  // au moment du choix (`applyAppearance`).
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: APPEARANCE_THEME_COLOR.day },
    { color: APPEARANCE_THEME_COLOR.day },
  ],
};

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const [locale, appearance] = await Promise.all([readUiLocale(), readAppearance()]);
  return (
    <html
      lang={UI_LOCALE_META[locale].html}
      data-appearance={appearance}
      className={`${hanken.variable} ${inter.variable} ${nunito.variable}${appearanceIsDark(appearance) ? " dark" : ""}`}
    >
      <head>
        <script dangerouslySetInnerHTML={{ __html: APPEARANCE_BOOT_SCRIPT }} />
      </head>
      <body className="relative antialiased">
        <I18nProvider locale={locale} messages={catalogFor(locale) as unknown as MessageTree}>
          <AppearanceProvider initial={appearance}>
            <SiteStructuredData />
            <div className="relative isolate flex min-h-svh flex-col bg-canvas text-ink">
              <PreviewBanner />
              <AuthReturnCatcher />
              {children}
            </div>
          </AppearanceProvider>
        </I18nProvider>
        {/*
          La mesure d'audience. Elle ne pose pas de cookie et ne reconnaît personne : une
          page vue, sa provenance, un pays, rien qui se recolle à un compte — c'est pour ça
          qu'elle n'appelle pas de bandeau de consentement.

          Ce qu'elle donne sans qu'on écrive un événement, c'est le parcours d'accueil : les
          treize écrans de `/commencer/*` sont treize adresses, donc treize lignes dans le
          tableau des pages vues, et l'écran où l'on décroche se lit dessus. Le reste se
          compte ailleurs — les comptes et l'accueil terminé en base, l'abonnement chez
          RevenueCat. `docs/mesure.md` dit qui répond à quoi.

          Les aperçus n'en produisent rien : le middleware les renvoie au site avant le rendu.
        */}
        <Analytics />
      </body>
    </html>
  );
}
