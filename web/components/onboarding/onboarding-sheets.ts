import type { SheetBlock } from "@micabo/core";

import { DEMO_SHEET } from "@/components/demo/demo-course";

/**
 * Trois fiches, **en vrais blocs**.
 *
 * Ce sont les mêmes `SheetBlock` que ceux que le serveur écrit et que la base
 * enregistre, rendus par le même composant que la fiche d'un vrai cours. Une
 * maquette dessinée à la main promettrait quelque chose que le produit ne rend
 * pas ; celles-ci sont ce qu'on obtient.
 *
 * Trois matières et trois formes différentes, choisies pour ça : un graphe, une
 * formule avec ses étapes, un tableau. Une démonstration qui n'aligne que des
 * paragraphes laisse croire qu'une fiche n'est que du texte.
 */

export interface ShowcaseSheet {
  emoji: string;
  subject: string;
  title: string;
  /** Teinte du cours : elle porte les filets et les accents de la fiche. */
  tint: string;
  blocks: SheetBlock[];
}

const DERIVATIVES: SheetBlock[] = [
  { type: "heading", level: 1, text: "Dériver un produit" },
  {
    type: "paragraph",
    text: "La dérivée d'un produit n'est **pas** le produit des dérivées. C'est l'erreur la plus coûteuse du chapitre, et elle se corrige en apprenant la formule dans le bon ordre.",
  },
  {
    type: "formula",
    latex: "(uv)' = u'v + uv'",
    caption: "On dérive l'un, on garde l'autre — puis l'inverse.",
  },
  {
    type: "steps",
    title: "Sur un exemple",
    items: [
      "On pose u = x² et v = sin(x).",
      "On dérive séparément : u' = 2x et v' = cos(x).",
      "On assemble : 2x·sin(x) + x²·cos(x).",
    ],
  },
  {
    type: "callout",
    tone: "attention",
    text: "==Le signe est un plus, pas un moins.== Le moins n'apparaît que dans la dérivée d'un **quotient**.",
  },
];

const REVOLUTION: SheetBlock[] = [
  { type: "heading", level: 1, text: "1789, en quatre dates" },
  {
    type: "table",
    title: "Ce que l'examen attend",
    headers: ["Date", "Événement", "Ce que ça change"],
    rows: [
      ["5 mai", "États généraux", "Les trois ordres se réunissent"],
      ["17 juin", "Assemblée nationale", "Le tiers état se déclare seul souverain"],
      ["14 juillet", "Prise de la Bastille", "Paris entre dans la révolution"],
      ["4 août", "Abolition des privilèges", "La société d'ordres tombe"],
    ],
    caption: "Quatre dates, quatre bascules — pas une chronologie de plus.",
  },
  {
    type: "definition",
    term: "Tiers état",
    text: "Tout ce qui n'est ni clergé ni noblesse : **98 % de la population**, et une voix sur trois.",
  },
  {
    type: "callout",
    tone: "essentiel",
    text: "La nuit du 4 août n'abolit pas la monarchie, elle abolit les **privilèges**. Le roi reste jusqu'en 1792.",
  },
];

export const SHOWCASE_SHEETS: readonly ShowcaseSheet[] = [
  {
    emoji: "💧",
    subject: "SVT",
    title: "Le cycle de l'eau",
    tint: "#3E6C8C",
    blocks: DEMO_SHEET,
  },
  {
    emoji: "📐",
    subject: "Mathématiques",
    title: "Dérivées",
    tint: "#0b8a66",
    blocks: DERIVATIVES,
  },
  {
    emoji: "🏛️",
    subject: "Histoire",
    title: "La Révolution française",
    tint: "#b3872b",
    blocks: REVOLUTION,
  },
];
