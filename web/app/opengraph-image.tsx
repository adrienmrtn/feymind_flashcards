import { ImageResponse } from "next/og";

import { en } from "@/lib/i18n/catalogs/en";

export const runtime = "edge";
export const alt = en.landing.siteTitle;
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

/**
 * L'image de partage par défaut.
 *
 * Sans elle, `summary_large_image` promettait une image que les réseaux ne
 * trouvaient pas. Ici elle est générée au build, sans fichier binaire à tenir.
 *
 * Une seule image pour toutes les langues (`/opengraph-image` ne porte pas de préfixe) :
 * elle parle donc la langue de base du site, l'anglais, et ses phrases viennent du catalogue.
 */
export default function OpenGraphImage() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
          padding: 72,
          background: "#f6f7f9",
          color: "#191c20",
          fontFamily: "Georgia, serif",
        }}
      >
        <div style={{ display: "flex", fontSize: 28, fontWeight: 700, letterSpacing: -0.5 }}>
          micabo
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: 18 }}>
          <div style={{ fontSize: 64, fontWeight: 700, lineHeight: 1.05, letterSpacing: -1.5 }}>
            {`${en.landing.titleBefore} ${en.landing.titleAccent}`}
          </div>
          <div style={{ fontSize: 28, color: "#52525b", lineHeight: 1.3 }}>
            {en.landing.ogDescriptionShort}
          </div>
        </div>
      </div>
    ),
    size,
  );
}
