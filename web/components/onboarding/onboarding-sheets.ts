import type { SheetBlock } from "@micabo/core";

import { localizedDemoSheet } from "@/components/demo/demo-course";
import type { Translator } from "@/lib/i18n/copy";

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

function derivatives(t: Translator): SheetBlock[] {
  return [
    { type: "heading", level: 1, text: t("demo.showcase.mathHeading") },
    { type: "paragraph", text: t("demo.showcase.mathParagraph") },
    {
      type: "formula",
      latex: "(uv)' = u'v + uv'",
      caption: t("demo.showcase.mathCaption"),
    },
    {
      type: "steps",
      title: t("demo.showcase.mathStepsTitle"),
      items: [
        t("demo.showcase.mathStep1"),
        t("demo.showcase.mathStep2"),
        t("demo.showcase.mathStep3"),
      ],
    },
    {
      type: "callout",
      tone: "attention",
      text: t("demo.showcase.mathCallout"),
    },
  ];
}

function revolution(t: Translator): SheetBlock[] {
  return [
    { type: "heading", level: 1, text: t("demo.showcase.histHeading") },
    {
      type: "table",
      title: t("demo.showcase.histTableTitle"),
      headers: [t("demo.showcase.histH1"), t("demo.showcase.histH2"), t("demo.showcase.histH3")],
      rows: [
        [t("demo.showcase.histR1c1"), t("demo.showcase.histR1c2"), t("demo.showcase.histR1c3")],
        [t("demo.showcase.histR2c1"), t("demo.showcase.histR2c2"), t("demo.showcase.histR2c3")],
        [t("demo.showcase.histR3c1"), t("demo.showcase.histR3c2"), t("demo.showcase.histR3c3")],
        [t("demo.showcase.histR4c1"), t("demo.showcase.histR4c2"), t("demo.showcase.histR4c3")],
      ],
      caption: t("demo.showcase.histCaption"),
    },
    {
      type: "definition",
      term: t("demo.showcase.histTerm"),
      text: t("demo.showcase.histDef"),
    },
    {
      type: "callout",
      tone: "essentiel",
      text: t("demo.showcase.histCallout"),
    },
  ];
}

export function showcaseSheets(t: Translator): readonly ShowcaseSheet[] {
  return [
    {
      emoji: "💧",
      subject: t("demo.showcase.waterSubject"),
      title: t("demo.courseTitle"),
      tint: "#3E6C8C",
      blocks: localizedDemoSheet(t),
    },
    {
      emoji: "📐",
      subject: t("demo.showcase.mathSubject"),
      title: t("demo.showcase.mathTitle"),
      tint: "#0b8a66",
      blocks: derivatives(t),
    },
    {
      emoji: "🏛️",
      subject: t("demo.showcase.histSubject"),
      title: t("demo.showcase.histTitle"),
      tint: "#b3872b",
      blocks: revolution(t),
    },
  ];
}
