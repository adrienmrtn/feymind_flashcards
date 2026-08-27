/**
 * Le verrou du gratuit, **aligné sur celui de l'app**.
 *
 * Il existe côté iOS — `Micabo/Services/ProAccess.swift` — et c'est lui qui fait foi. Les trois
 * nombres et la coupure de la fiche sont donc portés depuis `FreeTier` et `SheetGate`, pas décidés
 * ici : un cours flouté aux sept dixièmes sur le téléphone et à la moitié sur le web serait le même
 * produit qui dit deux choses. `test/entitlement.test.ts` reprend les valeurs de
 * `MicaboTests/FreemiumTests.swift`.
 *
 * ## Ce qui a changé à l'étape 5
 *
 * Le droit ne se devine plus : il se **lit dans `entitlements`**, écrite par le webhook RevenueCat.
 * Le verrou est donc vivant pour quiconque a une ligne — un achat fait sur l'iPhone ferme la porte
 * du gratuit sur le web dans la seconde, et c'est exactement ce qu'on voulait.
 *
 * Reste le cas de **l'absence de ligne**, et c'est le seul endroit où une décision de produit se
 * cache dans du code. `ASSUME_PRO_WITHOUT_ROW` dit ce qu'on fait de quelqu'un dont on ne sait
 * rien :
 *
 * - à `true`, il est traité comme abonné. C'est le réglage d'aujourd'hui, et il n'est pas de la
 *   complaisance : **il n'y a aucune façon de payer sur le web** — Stripe attend ses clés — donc
 *   fermer maintenant enfermerait dehors tout le monde sans porte de sortie ;
 * - à `false`, le gratuit s'applique pour de bon : un cours, sept dixièmes de sa fiche, cinq cartes
 *   par session.
 *
 * Le jour où l'encaissement existe, c'est cette ligne-là qui bascule, et rien d'autre.
 */

/**
 * Ce qu'on fait de quelqu'un qui n'a pas de ligne dans `entitlements`.
 *
 * À `true` : on le traite comme abonné, parce qu'il n'existe pas encore de façon de payer sur le
 * web. À `false` : le gratuit s'applique. **Une seule ligne à changer**, et c'est tout ce que
 * l'ouverture de l'encaissement demandera côté verrou.
 */
export const ASSUME_PRO_WITHOUT_ROW = true;

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
  /**
   * Vrai quand `isPro` vient du réglage d'absence de ligne, pas d'un achat.
   * Le paywall s'appuie là-dessus : on peut être « Pro » pour les portes
   * et encore « à convertir » pour l'offre.
   */
  assumed?: boolean;
  productId?: string | null;
  /**
   * D'où vient l'achat. C'est lui qui décide quel magasin ouvre « Gérer mon abonnement » — un
   * bouton qui ouvre le mauvais donne un écran vide et un message au support.
   *
   * `play_store` est là bien qu'il n'y ait pas d'app Android : le webhook normalise déjà cette
   * valeur, la contrainte de la table l'accepte, et un type plus étroit que la base est un type
   * qui mentira le jour où la donnée arrivera.
   */
  store?: "app_store" | "play_store" | "stripe" | "promotional" | null;
  periodType?: "trial" | "intro" | "normal" | null;
  expiresAt?: Date | null;
  willRenew?: boolean;
}

export const FREE: Entitlement = { isPro: false };
export const PRO: Entitlement = { isPro: true };

/**
 * Le droit **deviné** : pas de ligne, donc pas d'achat, mais le verrou reste ouvert.
 *
 * C'est ce qui permet de poser le paywall — l'étudiant n'a pas payé — sans lui fermer
 * les cours tant que Stripe n'est pas branché.
 */
export const ASSUMED_PRO: Entitlement = { isPro: true, assumed: true };

/**
 * Vrai seulement s'il y a **vraiment** un abonnement.
 *
 * `isPro` peut être vrai par complaisance (`ASSUME_PRO_WITHOUT_ROW`) : le paywall
 * ne doit pas se fier à ça, sinon il ne s'ouvre jamais.
 */
export function isPaid(right: Entitlement): boolean {
  return right.isPro && !right.assumed;
}

/**
 * Le droit effectif.
 *
 * Tant que le verrou n'est pas armé, tout le monde est Pro. Et quand il le sera : en cas de
 * désaccord entre le SDK et la table, **le plus généreux gagne** le temps d'une session —
 * enfermer dehors un étudiant qui paye est pire qu'une minute offerte.
 */
export function resolve(...sources: (Entitlement | null | undefined)[]): Entitlement {
  const known = sources.filter((source): source is Entitlement => Boolean(source));

  // Personne ne sait rien de cette personne : c'est le réglage ci-dessus qui décide.
  if (known.length === 0) return ASSUME_PRO_WITHOUT_ROW ? ASSUMED_PRO : FREE;

  // Le plus généreux gagne. Le SDK et la table doivent s'accorder ; quand ils divergent, enfermer
  // dehors un étudiant qui paye est pire qu'une minute offerte.
  return known.find((source) => source.isPro) ?? known[0] ?? FREE;
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
