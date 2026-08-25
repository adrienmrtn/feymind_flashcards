/**
 * Le verrou du gratuit, **aligné sur celui de l'app**.
 *
 * Il existe maintenant côté iOS — `Micabo/Services/ProAccess.swift`, arrivé après que ce plan a
 * été écrit — et c'est lui qui fait foi. Les trois nombres et la coupure de la fiche sont donc
 * portés depuis `FreeTier` et `SheetGate`, pas décidés ici : un cours flouté aux sept dixièmes
 * sur le téléphone et à la moitié sur le web serait le même produit qui dit deux choses.
 * `test/entitlement.test.ts` reprend les valeurs de `MicaboTests/FreemiumTests.swift`.
 *
 * **`ARMED` reste à `false`, et pas par paresse.** Sur l'iPhone, `ProAccess` lit un drapeau
 * local ; il n'y a pas encore de table `entitlements`, donc le site n'a **rien à lire**. Armer
 * le verrou maintenant reviendrait à enfermer dehors un étudiant qui vient de payer sur son
 * téléphone. L'interrupteur bascule à l'étape 5, quand le webhook RevenueCat écrira le droit en
 * base — c'est-à-dire quand la question aura une réponse.
 */

export const ARMED = false;

/** Le nom de l'entitlement chez RevenueCat. Il est déjà fixé par `docs/revenuecat.md`. */
export const ENTITLEMENT_ID = "pro";

/**
 * Ce que la version gratuite laisse faire, et rien de plus.
 *
 * Les nombres se répondent : un cours qu'on lit aux sept dixièmes, cinq cartes par session, un
 * seul import. Éparpillés dans les écrans, ils dériveraient au premier ajustement.
 */
export const FREE_TIER = {
  /**
   * Un cours importé, et un seul. Ce n'est pas zéro, et c'est le point : un paywall posé avant
   * le premier import demande de payer pour un produit qu'on n'a pas vu tourner sur ses propres
   * cours.
   */
  courses: 1,
  /**
   * La part de la fiche qui se lit sans payer. Sept dixièmes, pas la moitié : il faut que la
   * fiche ait le temps d'être utile avant de s'arrêter. Une coupure au milieu se lit comme une
   * démonstration, une coupure à la fin se lit comme un manque — et c'est le manque qui fait
   * payer.
   */
  readableSheetRatio: 0.7,
  /** Le nombre de cartes qu'une session gratuite sert avant de s'arrêter. */
  cardsPerSession: 5,
  /**
   * L'entraînement libre est réservé à Pro. C'est la seule limite qui ferme une porte entière
   * plutôt que d'en entrouvrir une : réviser ce qui est dû est le service que Micabo rend,
   * s'entraîner à volonté sur tout un paquet est ce qu'on fait la veille d'un partiel.
   */
  allowsPractice: false,
} as const;

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

// MARK: - Les portes

/** Ce dont la porte de l'import a besoin pour compter, et rien de plus. */
export interface CountedCourse {
  /**
   * Un cours repris dans la bibliothèque n'a rien coûté à produire : le faire compter dans le
   * quota ferait payer un import qu'on n'a pas fait.
   */
  isFromLibrary: boolean;
}

export function canImportCourse(entitlement: Entitlement, courses: CountedCourse[]): boolean {
  if (entitlement.isPro) return true;
  return courses.filter((course) => !course.isFromLibrary).length < FREE_TIER.courses;
}

export function canPractice(entitlement: Entitlement): boolean {
  return entitlement.isPro || FREE_TIER.allowsPractice;
}

/** Vrai à partir de la carte qui doit rester derrière le paywall. */
export function hasReachedSessionLimit(entitlement: Entitlement, answered: number): boolean {
  return !entitlement.isPro && answered >= FREE_TIER.cardsPerSession;
}

// MARK: - La coupure de la fiche

/**
 * Où s'arrête la lecture d'une fiche, pour qui n'est pas abonné.
 *
 * La coupure se compte **en blocs et non en caractères** : couper un paragraphe au septième
 * dixième de son texte donnerait une phrase interrompue au milieu d'un mot, ce qui ressemble à
 * un bug d'affichage plutôt qu'à une limite assumée.
 *
 * Toujours au moins un bloc lisible, et jamais plus qu'il n'y en a.
 */
export function sheetLockIndex(
  blockCount: number,
  ratio: number = FREE_TIER.readableSheetRatio,
): number {
  if (blockCount <= 0) return 0;
  const raw = Math.round(blockCount * ratio);
  return Math.max(1, Math.min(blockCount, raw));
}

/** Coupe la fiche en deux : ce qui se lit, ce qui se devine. */
export function splitSheet<Block>(
  blocks: Block[],
  entitlement: Entitlement,
  ratio: number = FREE_TIER.readableSheetRatio,
): { readable: Block[]; locked: Block[] } {
  if (entitlement.isPro || blocks.length === 0) return { readable: blocks, locked: [] };
  const index = sheetLockIndex(blocks.length, ratio);
  return { readable: blocks.slice(0, index), locked: blocks.slice(index) };
}

/**
 * La part de la fiche qui reste à lire, en pourcentage entier.
 *
 * C'est le nombre de la phrase du cadenas — « il te reste 30 % de ce cours à lire ». Il est
 * calculé et non écrit, pour la même raison que le pourcentage d'économie du paywall : une
 * valeur écrite à la main à côté d'un ratio qui la contredit est le genre de détail qu'on ne
 * remarque qu'en production.
 */
export function lockedSheetPercent(ratio: number = FREE_TIER.readableSheetRatio): number {
  return Math.round((1 - ratio) * 100);
}
