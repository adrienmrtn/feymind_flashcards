/**
 * **La taille de lecture d'une fiche.**
 *
 * Elle n'est pas une marque du texte, et c'est tout l'enjeu de ce fichier. Le gras, l'italique,
 * le barré et le surlignage appartiennent à la fiche : ils partent en base, l'iPhone les lit,
 * ils veulent dire quelque chose sur le cours. La taille du texte, non - elle appartient à
 * l'œil qui lit, à l'écran qui affiche, au moment de la journée. Un étudiant qui grossit sa
 * fiche à 22 heures ne décide rien sur le contenu, et il ne veut pas non plus la retrouver
 * énorme sur le téléphone de son camarade avec qui il l'a partagée.
 *
 * Elle vit donc **sur l'appareil**, dans `localStorage`, et s'applique à toute fiche que ce
 * navigateur ouvre : celle qu'on écrit, celle qu'on relit, un cours partagé, la partie
 * verrouillée d'une fiche gratuite. Une seule échelle, réglée une fois.
 *
 * Trois crans, pas un curseur : entre 0,95 et 1,05 personne ne voit la différence, et un
 * curseur invite à chercher la valeur juste là où trois boutons donnent la réponse.
 */

export const READING_SIZES = ["petit", "normal", "grand"] as const;

export type ReadingSize = (typeof READING_SIZES)[number];

export const DEFAULT_READING_SIZE: ReadingSize = "normal";

/** Ce que chaque cran fait à l'échelle. Le grand cran vise la lecture à bout de bras. */
export const READING_SCALE: Record<ReadingSize, number> = {
  petit: 0.9,
  normal: 1,
  grand: 1.18,
};

const STORAGE_KEY = "micabo.sheet.size";

export function isReadingSize(value: unknown): value is ReadingSize {
  return typeof value === "string" && READING_SIZES.includes(value as ReadingSize);
}

/**
 * La taille retenue sur cet appareil.
 *
 * Un accès à `localStorage` lève dans une fenêtre privée ou quand le navigateur bloque le
 * stockage : une préférence d'affichage ne doit jamais empêcher une fiche de s'ouvrir.
 */
export function readReadingSize(): ReadingSize {
  try {
    const stored = window.localStorage.getItem(STORAGE_KEY);
    return isReadingSize(stored) ? stored : DEFAULT_READING_SIZE;
  } catch {
    return DEFAULT_READING_SIZE;
  }
}

export function writeReadingSize(size: ReadingSize): void {
  try {
    window.localStorage.setItem(STORAGE_KEY, size);
  } catch {
    // Rien à faire : la taille vaudra pour cette page, et repartira au défaut ensuite.
  }
}

/** Le style à poser sur un `.sheet-doc`. */
export function readingStyle(size: ReadingSize): React.CSSProperties {
  return { "--sheet-scale": READING_SCALE[size] } as React.CSSProperties;
}
