import type { NextConfig } from "next";

const config: NextConfig = {
  // `@micabo/core` est publié en TypeScript source, sans étape de compilation : c'est ce qui
  // permet à un test de vitest et au site de lire exactement le même fichier. Next doit donc
  // le transpiler avec le reste de l'application.
  transpilePackages: ["@micabo/core"],

  typedRoutes: true,

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
