/**
 * Combien de cartes, par format.
 *
 * Port de `QuestionQuota` (`Micabo/Services/AIService.swift`). **Un nombre par format est une
 * commande, pas une autorisation** : ce qui vivait là-bas était une paire d'interrupteurs, ils
 * disaient « j'accepte des QCM » et le modèle en écrivait deux ou onze selon son humeur.
 *
 * Les bornes sont celles de l'app, au chiffre près, parce que c'est la même fonction Edge qui
 * reçoit le quota : deux plafonds différents des deux côtés, et la même demande donnerait deux
 * paquets différents selon l'appareil.
 */

export type CardKind = "basic" | "cloze" | "choice";

export interface QuestionQuota {
  basic: number;
  cloze: number;
  choice: number;
}

/** Douze cartes, en trois parts : de quoi couvrir un chapitre sans épreuve d'endurance. */
export const DEFAULT_QUOTA: QuestionQuota = { basic: 6, cloze: 3, choice: 3 };

/** Ce qu'un format accepte. Zéro veut dire « pas de ce format », et c'est légitime. */
export const PER_FORMAT_RANGE = { min: 0, max: 20 } as const;

/** Une carte ne fait pas une session, trente sont déjà trop pour une seule. */
export const TOTAL_RANGE = { min: 3, max: 30 } as const;

export const CARD_KINDS: readonly {
  kind: CardKind;
  emoji: string;
  title: string;
  detail: string;
}[] = [
  {
    kind: "basic",
    emoji: "🗂️",
    title: "Recto verso",
    detail: "Une question, une réponse.",
  },
  {
    kind: "cloze",
    emoji: "✏️",
    title: "Texte à trou",
    detail: "Une phrase du cours, un terme à retrouver.",
  },
  {
    kind: "choice",
    emoji: "🔤",
    title: "QCM",
    detail: "Une question, trois ou quatre propositions.",
  },
];

export function quotaTotal(quota: QuestionQuota): number {
  return quota.basic + quota.cloze + quota.choice;
}

export function countOf(quota: QuestionQuota, kind: CardKind): number {
  return quota[kind];
}

/** Chaque format dans ses bornes, sans toucher au total. La forme sous laquelle on retient. */
export function formatBounded(quota: QuestionQuota): QuestionQuota {
  return {
    basic: clampFormat(quota.basic),
    cloze: clampFormat(quota.cloze),
    choice: clampFormat(quota.choice),
  };
}

/**
 * Le quota ramené dans ses bornes, total compris. La forme sous laquelle il part au modèle.
 *
 * Un quota entièrement à zéro ne demande rien : plutôt que d'aller écrire zéro carte, on retombe
 * sur le recto verso, le seul format qui marche sur n'importe quel cours. Au-delà du plafond, on
 * rogne **le format le plus nombreux** d'abord, pour que les petites commandes soient respectées
 * à la carte près.
 */
export function clampQuota(quota: QuestionQuota): QuestionQuota {
  const result = formatBounded(quota);

  if (quotaTotal(result) === 0) {
    return { basic: TOTAL_RANGE.min, cloze: 0, choice: 0 };
  }

  while (quotaTotal(result) > TOTAL_RANGE.max) {
    if (result.basic >= result.cloze && result.basic >= result.choice) result.basic -= 1;
    else if (result.cloze >= result.choice) result.cloze -= 1;
    else result.choice -= 1;
  }

  // Sous le plancher, on complète en recto verso : c'est le format qu'on peut ajouter à
  // n'importe quel cours sans que la carte sonne faux.
  const total = quotaTotal(result);
  if (total < TOTAL_RANGE.min) result.basic += TOTAL_RANGE.min - total;

  return result;
}

/** Vrai quand le total interdit d'augmenter encore : le bouton « plus » s'éteint. */
export function isAtCap(quota: QuestionQuota): boolean {
  return quotaTotal(quota) >= TOTAL_RANGE.max;
}

function clampFormat(value: number): number {
  return Math.min(PER_FORMAT_RANGE.max, Math.max(PER_FORMAT_RANGE.min, Math.round(value)));
}
