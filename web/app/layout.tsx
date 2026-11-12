import type { Metadata, Viewport } from "next";
import localFont from "next/font/local";

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
import { APP_STORE_ID } from "@/lib/stores";
import { SiteStructuredData } from "@/components/landing/StructuredData";

import "./globals.css";

/**
 * **Deux familles, comme l'app** (direction artistique V3.3, `V3Font`).
 *
 * Les titres, les bulles de Mika, les boutons et les grands chiffres sont en **Sofia Sans
 * Condensed** Black (900), ExtraBold (800) pour un bouton secondaire ; tout le reste est en
 * police système (`--font-sans`). Nunito est sortie, du site comme de l'app.
 *
 * Les fichiers sont ceux de l'app, sous licence OFL (`app/fonts/OFL.txt`), réduits au latin
 * étendu, au grec et au cyrillique et convertis en WOFF2 (40 Ko chacun). L'arabe retombe sur
 * la police du système. `adjustFontFallback` dessine une police de repli aux mêmes mesures :
 * le titre ne saute pas quand la vraie arrive.
 */
const sofia = localFont({
  src: [
    { path: "./fonts/SofiaSansCondensed-ExtraBold.woff2", weight: "800", style: "normal" },
    { path: "./fonts/SofiaSansCondensed-Black.woff2", weight: "900", style: "normal" },
  ],
  variable: "--font-sofia",
  display: "swap",
  adjustFontFallback: "Arial",
  fallback: ["Arial Narrow", "system-ui", "sans-serif"],
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
    applicationName: "Micabo",
    // Canonique et hreflang : chaque page indexable les pose elle-même.
    // Les poser ici, sur `/`, ferait de toutes les pages un doublon de l'accueil.
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
    // La bannière de Safari sur iPhone : `<meta name="apple-itunes-app" content="app-id=…">`.
    // Elle propose d'ouvrir l'app (ou de l'installer) sans qu'on dessine rien.
    itunes: { appId: APP_STORE_ID },
    openGraph: {
      type: "website",
      siteName: "Micabo",
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
  // La couleur de la barre du navigateur suit le fond : le marine par défaut. Le clair la
  // remplace au moment du choix (`applyAppearance`, et le script d'amorçage).
  themeColor: [{ color: APPEARANCE_THEME_COLOR.night }],
};

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const [locale, appearance] = await Promise.all([readUiLocale(), readAppearance()]);
  return (
    <html
      lang={UI_LOCALE_META[locale].html}
      // L'arabe se lit de droite à gauche : tout le site se retourne avec lui (voir la fin de
      // `globals.css`, et les propriétés logiques `ps-` / `pe-` / `text-start`).
      dir={UI_LOCALE_META[locale].dir}
      data-appearance={appearance}
      className={`${sofia.variable}${appearanceIsDark(appearance) ? " dark" : ""}`}
      // Le script d'amorçage pose le même `color-scheme` avant l'hydratation : le serveur doit
      // l'écrire aussi, sinon React signale un attribut qu'il n'attendait pas.
      style={{ colorScheme: appearanceIsDark(appearance) ? "dark" : "light" }}
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
