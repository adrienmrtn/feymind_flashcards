import path from "node:path";

import type { NextConfig } from "next";

const config: NextConfig = {
  // À la racine du dépôt les dossiers de l'app sont des liens vers `web/`. Sans ça, le
  // collecteur de pages de Next cherche `_not-found` à côté du lien et ne le trouve pas.
  outputFileTracingRoot: path.join(process.cwd()),

  // `@micabo/core` est publié en TypeScript source, sans étape de compilation : c'est ce qui
  // permet à un test de vitest et au site de lire exactement le même fichier. Next doit donc
  // le transpiler avec le reste de l'application.
  transpilePackages: ["@micabo/core"],

  typedRoutes: true,

  // Une carte à occlusion envoie le schéma en data URL JPEG. Un schéma à 1200 px
  // tient largement sous 2 Mo ; le plafond par défaut (1 Mo) recassait l'enregistrement.
  experimental: {
    serverActions: {
      bodySizeLimit: "2mb",
    },
    // Next 15+ a mis ce délai à 0 : chaque clic attendait le serveur, même pour une
    // page visitée il y a dix secondes. Trente secondes suffisent à rendre la barre
    // instantanée, sans garder une session périmée.
    staleTimes: {
      dynamic: 30,
      static: 180,
    },
  },

  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          // La `Content-Security-Policy` arrive quand la liste des tiers sera arrêtée : posée
          // trop tôt, elle se relâche à chaque ajout et finit par tout autoriser.
        ],
      },
    ];
  },
};

export default config;
