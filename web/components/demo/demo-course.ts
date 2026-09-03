import type { SheetBlock } from "@micabo/core";

import type { Translator } from "@/lib/i18n/copy";

/**
 * Le document de démonstration, repris mot pour mot de
 * `Micabo/Features/Onboarding/Steps/OnboardingDemo.swift`.
 *
 * Le cycle de l'eau est vu partout, du collège au supérieur, et se dessine en trois temps :
 * c'est reconnaissable d'un coup d'œil, contrairement à un chapitre dense. Et c'est **le même
 * document que celui de l'app** : ce que le site promet est exactement ce que le parcours
 * d'accueil montre ensuite.
 *
 * Rien n'est appelé sur le réseau, rien n'est enregistré : la démonstration tourne en avion.
 */

export const DEMO_COURSE = {
  title: "Le cycle de l'eau",
  subject: "SVT",
  chapter: "Chapitre 4 · L'eau sur Terre",
  fileName: "Le cycle de l'eau.pdf",
  /** Bleu d'eau : la figure et les accents de la démonstration. */
  accent: "#3E6C8C",
} as const;

/**
 * Ce que contient le PDF déposé : un mur de texte sans hiérarchie.
 *
 * C'est **volontairement mal écrit** et volontairement dense. Sans un vrai avant, l'après ne
 * transforme rien - et le titre est perdu au milieu du texte, à la même taille que le reste,
 * ce qui est exactement ce qui rend un polycopié pénible à réviser.
 */
export const RAW_LINES: readonly string[] = [
  "Le cycle de l'eau désigne l'ensemble des mouvements de l'eau entre les océans, l'atmosphère et les continents.",
  "Sous l'effet du rayonnement solaire l'eau de surface passe à l'état de vapeur, ce phénomène est appelé évaporation et concerne surtout les océans qui couvrent 71 % de la surface terrestre.",
  "La vapeur d'eau s'élève et rencontre des couches plus froides, elle se condense alors autour de noyaux de condensation pour former des gouttelettes qui constituent les nuages.",
  "Lorsque les gouttelettes deviennent trop lourdes elles retombent sous forme de précipitations, pluie ou neige selon la température rencontrée pendant la chute.",
  "Une partie de cette eau ruisselle et rejoint les cours d'eau puis les océans, une autre s'infiltre dans le sol et alimente les nappes phréatiques.",
];

/**
 * La fiche, en **vrais blocs** - pas une maquette.
 *
 * C'est le même type `SheetBlock` que celui que le serveur écrit et que la base enregistre, et
 * elle est rendue par le même composant que la fiche d'un vrai cours. C'est ce qui fait que la
 * page d'accueil montre le produit au lieu de le représenter.
 *
 * Le balisage est celui de l'app : `**gras**` pour le mot que l'examen attend, `==surligné==`
 * pour ce qu'on relit la veille.
 */
export const DEMO_SHEET: SheetBlock[] = [
  { type: "heading", level: 1, text: "Trois temps, une boucle" },
  {
    type: "paragraph",
    text: "L'eau change d'état sans jamais quitter la planète : ce qui s'**évapore** des océans retombe sur les continents, puis y retourne. ==71 % de l'évaporation vient des océans.==",
  },
  {
    type: "definition",
    term: "Condensation",
    text: "Passage de la vapeur à l'état liquide, autour de **noyaux de condensation**.",
  },
  {
    type: "chart",
    title: "D'où vient l'eau qui s'évapore",
    unit: "%",
    bars: [
      { label: "Océans", value: 71 },
      { label: "Continents", value: 29 },
    ],
    caption: "Les océans couvrent 71 % de la surface terrestre.",
  },
  {
    type: "callout",
    tone: "attention",
    text: "Pluie ou neige ne dépend pas de l'altitude du nuage mais de la **température rencontrée pendant la chute**.",
  },
];

/**
 * La fiche de la section de transformation, un bloc plus courte.
 *
 * L'encadré « Attention » en est retiré, et pour une raison de mise en page qui compte : cette
 * section tient les deux états dans **un seul rectangle**, et ce rectangle doit entrer en entier
 * dans un écran de portable sans être rogné. Une fiche rognée à mi-hauteur ne montre pas une
 * transformation, elle montre un défaut d'affichage.
 *
 * Ce qui reste couvre déjà tout ce que la section a à prouver : un plan, de la prose, une
 * définition, un objet chiffré, et le schéma.
 */
export const TRANSFORMATION_SHEET: SheetBlock[] = DEMO_SHEET.filter(
  (block) => block.type !== "callout",
);

/** Les trois temps du cycle, pour la figure. */
export const CYCLE_STAGES = [
  { label: "Évaporation", tint: "var(--color-caution-vivid)" },
  { label: "Condensation", tint: "var(--color-ink-secondary)" },
  { label: "Précipitations", tint: DEMO_COURSE.accent },
] as const;

/**
 * Les cartes que Micabo tire de cette fiche.
 *
 * Trois formats, parce qu'une démonstration qui ne montre que du recto verso laisse croire que
 * Micabo ne fait que du recto verso.
 */
export type DemoCardKind = "basic" | "choice" | "gap" | "diagram";

export interface DemoCard {
  kind: DemoCardKind;
  kindLabel: string;
  front: string;
  back: string;
  choices?: string[];
  answerIndex?: number;
  /** Ce que le verso ajoute quand la réponse mérite une raison, pas seulement un mot. */
  note?: string;
  /**
   * Les étiquettes d'un schéma à compléter, dans l'ordre du cycle. La carte à schéma est le
   * quatrième format de l'app, et c'est celui qu'une démonstration oublie toujours d'annoncer.
   */
  labels?: readonly { text: string; hidden?: boolean }[];
}

export const DEMO_CARDS: readonly DemoCard[] = [
  {
    kind: "basic",
    kindLabel: "Recto verso",
    front: "Que fait le soleil à l'eau des océans ?",
    back: "Il la fait s'évaporer.",
    note: "71 % de l'évaporation mondiale vient des océans.",
  },
  {
    kind: "choice",
    kindLabel: "QCM",
    front: "Où la vapeur se condense-t-elle ?",
    back: "En altitude, où l'air est plus froid.",
    choices: ["En altitude", "Au ras du sol", "Sous la mer"],
    answerIndex: 0,
  },
  {
    kind: "gap",
    kindLabel: "Texte à trou",
    front: "Les gouttelettes trop lourdes retombent en …",
    back: "précipitations",
    note: "Pluie ou neige, selon la température rencontrée pendant la chute.",
  },
  {
    kind: "diagram",
    kindLabel: "Schéma",
    front: "Nomme les trois temps du cycle.",
    back: "Évaporation, condensation, précipitations.",
    labels: [
      { text: "Évaporation", hidden: true },
      { text: "Condensation", hidden: true },
      { text: "Précipitations", hidden: true },
    ],
  },
];

export const DEMO_ACCENT = DEMO_COURSE.accent;

export function localizedDemoCourse(t: Translator) {
  return {
    title: t("demo.courseTitle"),
    subject: t("demo.showcase.waterSubject"),
    chapter: t("demo.chapter"),
    fileName: t("demo.fileName"),
    accent: DEMO_ACCENT,
  };
}

export function localizedRawLines(t: Translator): readonly string[] {
  return [t("demo.raw1"), t("demo.raw2"), t("demo.raw3"), t("demo.raw4"), t("demo.raw5")];
}

export function localizedDemoSheet(t: Translator): SheetBlock[] {
  return [
    { type: "heading", level: 1, text: t("demo.sheetHeading") },
    { type: "paragraph", text: t("demo.sheetParagraphMarked") },
    { type: "definition", term: t("demo.defTerm"), text: t("demo.defText") },
    {
      type: "chart",
      title: t("demo.chartTitle"),
      unit: "%",
      bars: [
        { label: t("demo.oceans"), value: 71 },
        { label: t("demo.continents"), value: 29 },
      ],
      caption: t("demo.chartCaption"),
    },
    { type: "callout", tone: "attention", text: t("demo.sheetCallout") },
  ];
}

export function localizedTransformationSheet(t: Translator): SheetBlock[] {
  return localizedDemoSheet(t).filter((block) => block.type !== "callout");
}

export function localizedCycleStages(t: Translator) {
  return [
    { label: t("demo.evap"), tint: "var(--color-caution-vivid)" },
    { label: t("demo.cond"), tint: "var(--color-ink-secondary)" },
    { label: t("demo.precip"), tint: DEMO_ACCENT },
  ] as const;
}

export function localizedDemoCards(t: Translator): readonly DemoCard[] {
  return [
    {
      kind: "basic",
      kindLabel: t("demo.card1Kind"),
      front: t("demo.card1Front"),
      back: t("demo.card1Back"),
      note: t("demo.card1Note"),
    },
    {
      kind: "choice",
      kindLabel: t("demo.card2Kind"),
      front: t("demo.card2Front"),
      back: t("demo.card2Back"),
      choices: [t("demo.card2c1"), t("demo.card2c2"), t("demo.card2c3")],
      answerIndex: 0,
    },
    {
      kind: "gap",
      kindLabel: t("demo.card3Kind"),
      front: t("demo.card3Front"),
      back: t("demo.card3Back"),
      note: t("demo.card3Note"),
    },
    {
      kind: "diagram",
      kindLabel: t("demo.card4Kind"),
      front: t("demo.card4Front"),
      back: t("demo.card4Back"),
      labels: [
        { text: t("demo.evap"), hidden: true },
        { text: t("demo.cond"), hidden: true },
        { text: t("demo.precip"), hidden: true },
      ],
    },
  ];
}
