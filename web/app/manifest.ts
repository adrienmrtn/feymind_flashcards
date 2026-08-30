import type { MetadataRoute } from "next";

/**
 * Le manifeste, pour l'icône d'un site épinglé et le nom sous cette icône.
 *
 * `name` porte la phrase, `short_name` porte le mot : c'est `short_name` qui s'affiche sous
 * l'icône d'un écran d'accueil, et il est coupé au-delà d'une douzaine de caractères.
 *
 * Les icônes vivent dans `public/`, à des adresses fixes : `icon.svg` sert d'abord, et les
 * PNG prennent le relais là où le SVG n'est pas lu (Android, Windows). `purpose: "maskable"`
 * autorise Android à rogner l'icône en cercle sans manger la lettre — c'est le seul cas où
 * une icône a besoin d'une version à part, avec de la marge autour du dessin.
 *
 * Les PNG ne sont pas encore dans le dépôt. Un manifeste qui déclare une icône absente ne
 * casse rien : le navigateur retombe sur le SVG. `docs/seo.md` dit quoi déposer.
 */
export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Micabo - fiches et flashcards à partir de tes cours",
    short_name: "Micabo",
    description:
      "Dépose un cours. Micabo en écrit la fiche, en tire les cartes, et les fait revenir avant que tu l'oublies.",
    start_url: "/",
    display: "standalone",
    background_color: "#f6f7f9",
    theme_color: "#f6f7f9",
    lang: "fr",
    icons: [
      { src: "/icon.svg", type: "image/svg+xml", sizes: "any" },
      { src: "/icon-192.png", type: "image/png", sizes: "192x192" },
      { src: "/icon-512.png", type: "image/png", sizes: "512x512" },
      {
        src: "/icon-maskable-512.png",
        type: "image/png",
        sizes: "512x512",
        purpose: "maskable",
      },
    ],
  };
}
