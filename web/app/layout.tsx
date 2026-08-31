import type { Metadata, Viewport } from "next";
import { Hanken_Grotesk, Inter, Nunito } from "next/font/google";

import { AuthReturnCatcher } from "@/components/landing/AuthReturnCatcher";
import { PreviewBanner } from "@/components/PreviewBanner";
import { CANONICAL_URL, IS_INDEXABLE, SITE_URL } from "@/lib/config";
import { SiteStructuredData } from "@/components/landing/StructuredData";

import "./globals.css";

/**
 * Hanken Grotesk écrit les mots. C'est la police embarquée de l'app
 * (`Micabo/Resources/Fonts/`), reprise ici depuis Google Fonts en variable : `next/font`
 * l'héberge lui-même au moment de la compilation, donc aucun appel à un tiers à l'exécution.
 */
const hanken = Hanken_Grotesk({
  subsets: ["latin"],
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
  subsets: ["latin"],
  weight: ["600", "700", "800"],
  variable: "--font-nunito",
  display: "swap",
});

/** Inter porte l'app connectée — le même corps que micabo OS. */
const inter = Inter({
  subsets: ["latin"],
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
export const metadata: Metadata = {
  metadataBase: new URL(IS_INDEXABLE ? CANONICAL_URL : SITE_URL),
  title: {
    default: "Micabo - fiches et flashcards à partir de tes cours",
    template: "%s - Micabo",
  },
  description:
    "Dépose un polycopié, une photo de tes notes ou une vidéo de cours. Micabo en écrit la fiche que tu relis, en tire les cartes qui te la font retenir, et les fait revenir juste avant que tu l'oublies.",
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
    locale: "fr_FR",
    url: "/",
    title: "Micabo - fiches et flashcards à partir de tes cours",
    description:
      "Ton cours devient une fiche qu'on relit, et des cartes qui reviennent au bon moment. Sur le web et sur iPhone.",
  },
  twitter: {
    card: "summary_large_image",
    title: "Micabo - fiches et flashcards à partir de tes cours",
    description:
      "Ton cours devient une fiche qu'on relit, et des cartes qui reviennent au bon moment.",
  },
};

export const viewport: Viewport = {
  // La couleur de la barre du navigateur suit le papier : une bande blanche au-dessus d'un fond
  // teinté fait lire une bordure là où il n'y en a pas.
  themeColor: "#f6f7f9",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="fr" className={`${hanken.variable} ${inter.variable} ${nunito.variable}`}>
      <body className="relative antialiased">
        <SiteStructuredData />
        <div className="relative isolate flex min-h-svh flex-col">
          <PreviewBanner />
          <AuthReturnCatcher />
          {children}
        </div>
      </body>
    </html>
  );
}
