import type { Metadata, Viewport } from "next";
import { Hanken_Grotesk, Nunito } from "next/font/google";

import { AuthReturnCatcher } from "@/components/landing/AuthReturnCatcher";
import { PreviewBanner } from "@/components/PreviewBanner";
import { IS_INDEXABLE, SITE_URL } from "@/lib/config";

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
 * parce qu'elle ne compose jamais un mot — une police qu'on ne voit que sur des chiffres ne se
 * reconnaît pas.
 */
const nunito = Nunito({
  subsets: ["latin"],
  weight: ["600", "700", "800"],
  variable: "--font-nunito",
  display: "swap",
});

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: "Micabo",
  description: "Ton cours devient une fiche. Puis des cartes. Puis ça reste.",
  robots: IS_INDEXABLE ? undefined : { index: false, follow: false },
};

export const viewport: Viewport = {
  // La couleur de la barre du navigateur suit le papier : une bande blanche au-dessus d'un fond
  // ivoire fait lire une bordure là où il n'y en a pas.
  themeColor: "#f6f4ed",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="fr" className={`${hanken.variable} ${nunito.variable}`}>
      <body>
        <PreviewBanner />
        <AuthReturnCatcher />
        {children}
      </body>
    </html>
  );
}
