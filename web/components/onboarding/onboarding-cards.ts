import type { Translator } from "@/lib/i18n/copy";

/**
 * Les cartes du parcours, **au format des vraies.**
 *
 * Recto, indice, verso, et pour le QCM ses propositions : c'est exactement ce
 * qu'une session sert. Les cartes de la vitrine n'ont pas d'indice parce
 * qu'elles pivotent en vitrine ; ici on montre une session, donc l'indice est
 * là où il sera vraiment — replié sous le recto, à ouvrir si on cale.
 */

export interface StoryCard {
  kindLabel: string;
  front: string;
  back: string;
  hint?: string;
  choices?: readonly string[];
  answerIndex?: number;
  /** Ce que le verso ajoute quand la réponse mérite une raison, pas seulement un mot. */
  note?: string;
}

export const STORY_CARDS: readonly StoryCard[] = [
  {
    kindLabel: "Recto verso",
    front: "Que fait le soleil à l'eau des océans ?",
    back: "Il la fait s'évaporer.",
    hint: "Elle change d'état, elle ne disparaît pas.",
    note: "71 % de l'évaporation mondiale vient des océans.",
  },
  {
    kindLabel: "QCM",
    front: "Où la vapeur d'eau se condense-t-elle ?",
    back: "En altitude, où l'air est plus froid.",
    hint: "Pense à la température, pas à la distance.",
    choices: ["En altitude", "Au ras du sol", "Sous la mer"],
    answerIndex: 0,
  },
  {
    kindLabel: "Texte à trou",
    front: "Les gouttelettes trop lourdes retombent en …",
    back: "précipitations",
    hint: "Pluie ou neige, c'est le même mot qui les couvre.",
    note: "Ce qui décide entre les deux, c'est la température rencontrée pendant la chute.",
  },
];

export function localizedStoryCards(t: Translator): readonly StoryCard[] {
  return [
    {
      kindLabel: t("demo.card1Kind"),
      front: t("demo.card1Front"),
      back: t("demo.card1Back"),
      hint: t("demo.card1Hint"),
      note: t("demo.card1Note"),
    },
    {
      kindLabel: t("demo.card2Kind"),
      front: t("demo.card2Front"),
      back: t("demo.card2Back"),
      hint: t("demo.card2Hint"),
      choices: [t("demo.card2c1"), t("demo.card2c2"), t("demo.card2c3")],
      answerIndex: 0,
    },
    {
      kindLabel: t("demo.card3Kind"),
      front: t("demo.card3Front"),
      back: t("demo.card3Back"),
      hint: t("demo.card3Hint"),
      note: t("demo.card3Note"),
    },
  ];
}
