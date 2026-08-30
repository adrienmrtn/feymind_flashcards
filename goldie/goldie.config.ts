import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

/**
 * Captures App Store de Micabo. Les flux vivent dans `.argent/flows`.
 * `out/` est créé à côté de ce fichier.
 *
 * Le bundle Release se trouve en lançant une archive simulateur, ou :
 *   find ~/Library/Developer/Xcode/DerivedData -name Micabo.app \
 *     -path '*Release-iphonesimulator*' | head -1
 *
 * Puis : `export MICABO_APP=/ce/chemin/Micabo.app`
 */
const APP_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const config = {
  appRoot: APP_ROOT,
  appPath:
    process.env.MICABO_APP ??
    `${process.env.HOME}/Library/Developer/Xcode/DerivedData/Micabo/Build/Products/Release-iphonesimulator/Micabo.app`,
  bundleId: "com.micabo.app",

  devices: ["iphone-6.9"],
  locales: ["fr-FR"],
  appearance: "light" as const,

  frame: { variant: "17-pro-silver" as const },

  theme: {
    background: "linear-gradient(168deg, #DCE8DC 0%, #E8EFE6 38%, #F6F4ED 72%, #FFFDF6 100%)",
    headlineColor: "#191714",
    subheadColor: "#6F6A60",
    fontFamily: '"DM Sans", -apple-system, "SF Pro Display", system-ui, sans-serif',
    copyHeightRatio: 0.22,
    deviceWidthRatio: 0.86,
    template: "editorial" as const,
    layout: "classic" as const,
  },

  store: {
    name: "Micabo",
    subtitle: { "fr-FR": "Apprends tout, plus vite" },
    developer: "Micabo",
    category: "Éducation",
    rating: 4.9,
    ratingCount: "128 Notes",
    ageRating: "4+",
    price: "Gratuit",
    description: {
      "fr-FR": [
        "Dépose un polycopié, une photo de tes notes ou une vidéo de cours. Micabo en écrit la fiche que tu relis, en tire les cartes, et les fait revenir juste avant que tu oublies.",
        "Tu donnes la date de l'examen. Le plan se resserre à l'approche du jour J. Relire ne suffit pas. Se souvenir, oui.",
      ].join("\n\n"),
    },
  },

  scenes: [
    {
      kind: "screenshot" as const,
      id: "today",
      flow: "store-01-today",
      headline: { "fr-FR": "Juste avant l'oubli" },
      subhead: {
        "fr-FR": "Tes cartes reviennent le jour où tu commences à les perdre.",
      },
    },
    {
      kind: "screenshot" as const,
      id: "sheet",
      flow: "store-02-sheet",
      headline: { "fr-FR": "Le cours, déjà fiché" },
      subhead: {
        "fr-FR": "Dépose tes notes. Micabo écrit la fiche que tu relis.",
      },
    },
    {
      kind: "screenshot" as const,
      id: "study",
      flow: "store-03-study",
      headline: { "fr-FR": "Tu te souviens, ou pas" },
      subhead: {
        "fr-FR": "Quatre notes. Le plan suit. Rien d'autre à décider.",
      },
    },
    {
      kind: "screenshot" as const,
      id: "exam",
      flow: "store-04-exam",
      headline: { "fr-FR": "Le jour J commande" },
      subhead: {
        "fr-FR": "Tu donnes la date. Micabo resserre les cartes à l'approche.",
      },
    },
    {
      kind: "screenshot" as const,
      id: "courses",
      flow: "store-05-courses",
      headline: { "fr-FR": "PDF, photo ou vidéo" },
      subhead: {
        "fr-FR": "Tes cours deviennent des fiches, puis des cartes.",
      },
    },
    {
      kind: "preview" as const,
      id: "preview",
      segments: [
        { id: "open", flow: "store-preview-01-open", holdSeconds: 1.4 },
        { id: "start", flow: "store-preview-02-start" },
        { id: "reveal", flow: "store-preview-03-reveal", holdSeconds: 1.6 },
        { id: "grade", flow: "store-preview-04-grade", holdSeconds: 2 },
      ],
    },
  ],
};

export default config;
