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
