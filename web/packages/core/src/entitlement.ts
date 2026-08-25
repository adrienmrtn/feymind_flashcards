/**
 * Le verrou du gratuit — **construit, pas armé.**
 *
 * Il n'existe nulle part aujourd'hui : aucun test de droit dans l'app iOS, aucune table
 * `entitlements`, et tout compte connecté est de fait Pro. Ce module est donc le premier
 * endroit du produit où la question se pose, et il est écrit pour qu'elle ne se pose qu'ici :
 * une fonction pure, appelée par un composant de flou, jamais un `if` recopié dans six écrans.
 *
 * **`ARMED` est à `false` jusqu'à l'étape 5.** Livrer un site qui floute des fiches avant
 * qu'on puisse les déverrouiller en payant serait livrer une panne. L'armer, ensuite, est
 * cette ligne-là.
 *
 * La forme du verrou est délibérée : **on génère, puis on floute.** On dépose son polycopié,
 * on regarde Micabo travailler, la fiche apparaît — et c'est à ce moment-là qu'elle se
 * referme. Bloquer l'import serait moins cher en appels au modèle et beaucoup moins efficace :
 * on ne désire pas ce qu'on n'a pas vu.
 */

export const ARMED = false;

/** Ce que le webhook RevenueCat écrira dans `entitlements`, à l'étape 5. */
export interface Entitlement {
  isPro: boolean;
  productId?: string | null;
  /** D'où vient l'achat. C'est lui qui décide quel magasin ouvre « Gérer mon abonnement ». */
  store?: "app_store" | "stripe" | "promotional" | null;
  periodType?: "trial" | "intro" | "normal" | null;
  expiresAt?: Date | null;
  willRenew?: boolean;
}

export const FREE: Entitlement = { isPro: false };
export const PRO: Entitlement = { isPro: true };

/** Les plafonds du palier gratuit. Chacun est une constante, donc chacun se change seul. */
export const FREE_LIMITS = {
  /** Fiches entièrement lisibles. La première prouve la qualité, les suivantes la vendent. */
  fullSheets: 1,
  /** Blocs lisibles d'une fiche verrouillée, chapeau compris. */
  visibleBlocks: 3,
  /** Cartes utilisables par cours. Les suivantes sont dans la liste, floutées. */
  cardsPerCourse: 10,
} as const;

/**
 * Le droit effectif.
 *
 * Tant que le verrou n'est pas armé, tout le monde est Pro. Et quand il le sera : en cas de
 * désaccord entre le SDK et la table, **le plus généreux gagne** le temps d'une session —
 * enfermer dehors un étudiant qui paye est pire qu'une minute offerte.
 */
export function resolve(...sources: (Entitlement | null | undefined)[]): Entitlement {
  if (!ARMED) return PRO;
  const known = sources.filter((source): source is Entitlement => Boolean(source));
  if (known.length === 0) return FREE;
  return known.find((source) => source.isPro) ?? FREE;
}

export type LockReason = "sheetBeyondFree" | "cardBeyondFree" | "examMode";

export interface Lock {
  locked: boolean;
  reason?: LockReason;
}

const OPEN: Lock = { locked: false };

/**
 * Une fiche est-elle lisible en entier ?
 *
 * `rank` est le rang du cours dans la bibliothèque de l'étudiant, du plus ancien au plus
 * récent, à partir de zéro. C'est le rang et non la date qui décide : sinon le premier cours
 * se refermerait tout seul le jour où l'étudiant en importe un deuxième.
 */
export function sheetLock(entitlement: Entitlement, rank: number): Lock {
  if (entitlement.isPro) return OPEN;
  if (rank < FREE_LIMITS.fullSheets) return OPEN;
  return { locked: true, reason: "sheetBeyondFree" };
}

/** Combien de blocs d'une fiche se lisent, pour ce droit et ce rang. */
export function visibleBlockCount(
  entitlement: Entitlement,
  rank: number,
  blockCount: number,
): number {
  return sheetLock(entitlement, rank).locked
    ? Math.min(FREE_LIMITS.visibleBlocks, blockCount)
    : blockCount;
}

/** Une carte est-elle utilisable ? `index` est son rang dans son cours, à partir de zéro. */
export function cardLock(entitlement: Entitlement, index: number): Lock {
  if (entitlement.isPro) return OPEN;
  if (index < FREE_LIMITS.cardsPerCourse) return OPEN;
  return { locked: true, reason: "cardBeyondFree" };
}

/**
 * Le mode examen est réservé, et c'est cohérent : le parcours d'accueil demande la date de
 * l'examen, promet « un parcours adapté à ton examen », et le paywall arrive trois écrans plus
 * loin. Le verrou est posé exactement sur ce qui vient d'être promis.
 */
export function examModeLock(entitlement: Entitlement): Lock {
  return entitlement.isPro ? OPEN : { locked: true, reason: "examMode" };
}
