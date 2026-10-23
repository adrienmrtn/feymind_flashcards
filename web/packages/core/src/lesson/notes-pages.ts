import { blockIsBoxed, blockWordCount, type NoteBlock, type ThemeNotes } from "./types";

/**
 * **Les écrans d'une étape Notes**, et le glissé qui les tourne. Jumeau de `NotesPage` et
 * `NotesSwipe` dans `Micabo/Features/Lesson/NotesCircleView.swift`.
 *
 * Une étape Notes se lit en écrans courts : l'idée du thème, puis un écran par bloc (ou par
 * petit groupe de blocs), « À retenir », et la question de fin. Un ancien chapitre, sans notes
 * au format de la refonte, se lit en un seul écran.
 */

export type NotesPage =
  /** L'icône, le titre du thème et son idée en une phrase. */
  | { type: "opening" }
  /**
   * Des blocs des notes, `[start, end)` : un sous-titre et le bloc qu'il ouvre, ou un bloc
   * seul ; un encadré qui suit un bloc reste avec lui, et un bloc seul partage son écran.
   */
  | { type: "blocks"; start: number; end: number }
  | { type: "takeaways" }
  /** Un ancien chapitre : toute sa fiche d'un coup. */
  | { type: "legacy" }
  | { type: "question" };

/** Ce qu'un écran porte sans qu'il faille faire défiler, en mots pondérés (`screenWeight`). */
export const SCREEN_WEIGHT = 150;
/** En deçà, un bloc seul laisse l'écran à moitié vide : il accueille le suivant. */
export const THIN_WEIGHT = 120;

export function notesPages(notes: ThemeNotes | null, hasQuestion: boolean): NotesPage[] {
  const pages: NotesPage[] = [];
  if (notes) {
    pages.push({ type: "opening" });
    for (const [start, end] of noteScreens(notes.blocks)) pages.push({ type: "blocks", start, end });
    if (notes.takeaways.length > 0) pages.push({ type: "takeaways" });
  } else {
    pages.push({ type: "legacy" });
  }
  if (hasQuestion) pages.push({ type: "question" });
  return pages;
}

/** La place qu'un écran demande : ses mots, et le cadre de ce qui se dessine en encadré. */
export function screenWeight(blocks: readonly NoteBlock[]): number {
  return blocks.reduce((total, block) => {
    let frame: number;
    switch (block.type) {
      case "subtitle":
        frame = 6;
        break;
      case "paragraph":
        frame = 0;
        break;
      case "list":
      case "steps":
        frame = 4 * block.items.length;
        break;
      case "table":
        frame = 18 + 6 * block.rows.length;
        break;
      case "dates":
        frame = 18 + 4 * block.items.length;
        break;
      default:
        frame = 18;
    }
    return total + blockWordCount(block) + frame;
  }, 0);
}

/** Un seul bloc à lire, et assez court pour laisser de la place. */
function isThin(screen: readonly NoteBlock[]): boolean {
  const content = screen.filter((block) => block.type !== "subtitle");
  if (content.length !== 1) return false;
  const block = content[0]!;
  if (block.type === "callout") return false;
  return screenWeight([block]) < THIN_WEIGHT;
}

/**
 * La fin d'un écran ouvert à `index` : le bloc, celui qu'ouvre un sous-titre, et l'encadré
 * qui les commente.
 */
function screenEnd(blocks: readonly NoteBlock[], index: number): number {
  let end = index + 1;
  if (blocks[index]!.type === "subtitle" && end < blocks.length) end += 1;
  // Un encadré (le piège, l'astuce) commente le bloc qui le précède : il reste sur son écran,
  // au lieu d'arriver seul, détaché de ce qu'il explique.
  if (end < blocks.length && blocks[end]!.type === "callout" && !blockIsBoxed(blocks[end - 1]!)) {
    end += 1;
  }
  return end;
}

/**
 * **Les écrans des notes.** Un bloc par écran faisait des pages d'un paragraphe sur un fond
 * vide, qui se lisaient comme un mur de texte sans rien autour. Un écran qui n'a qu'un bloc
 * (le sous-titre qui l'ouvre ne compte pas) accueille donc le suivant, avec son sous-titre et
 * son encadré, tant que le tout tient sans défiler. Et un bloc resté seul (le dernier du
 * thème, ou trop long pour accueillir la suite) rejoint l'écran d'avant s'il y tient.
 *
 * Un encadré en tête de thème garde son écran : il annonce ce qui suit, il ne commente rien,
 * et le noyer dans le bloc suivant lui ôterait sa raison d'être.
 */
export function noteScreens(blocks: readonly NoteBlock[]): [number, number][] {
  const screens: [number, number][] = [];
  let index = 0;
  while (index < blocks.length) {
    let end = screenEnd(blocks, index);
    if (isThin(blocks.slice(index, end)) && end < blocks.length) {
      const next = screenEnd(blocks, end);
      if (screenWeight(blocks.slice(index, next)) <= SCREEN_WEIGHT) end = next;
    }
    screens.push([index, end]);
    index = end;
  }

  const packed: [number, number][] = [];
  for (const screen of screens) {
    const last = packed[packed.length - 1];
    if (last && isThin(blocks.slice(screen[0], screen[1])) && screenWeight(blocks.slice(last[0], screen[1])) <= SCREEN_WEIGHT) {
      packed[packed.length - 1] = [last[0], screen[1]];
    } else {
      packed.push(screen);
    }
  }
  return packed;
}

// MARK: - Le glissé

export type SwipeDirection = "forward" | "back";

/** La longueur d'un glissé qui tourne la page. */
export const SWIPE_DISTANCE = 70;
/** La longueur où le geste, lancé, serait arrivé : un geste court mais vif tourne aussi. */
export const SWIPE_FLICK = 160;
/** De combien le geste doit être plus large que haut. */
export const SWIPE_SLANT = 2.2;

/**
 * **Le glissé qui tourne une page de notes, et ceux qui ne la tournent pas.** Le geste doit
 * être nettement horizontal, et assez long, ou lancé assez vite. Un défilement vertical qui
 * dérive un peu ne tourne rien. En écriture de droite à gauche, la page suivante arrive par la
 * gauche, et c'est un glissé vers la droite qui l'amène.
 */
export function swipeDirection(
  translation: { width: number; height: number },
  predicted: { width: number; height: number } = translation,
  rightToLeft = false,
): SwipeDirection | null {
  const dx = translation.width;
  if (Math.abs(dx) <= SWIPE_SLANT * Math.abs(translation.height)) return null;
  const long = Math.abs(dx) >= SWIPE_DISTANCE;
  const flung =
    Math.abs(dx) >= SWIPE_DISTANCE / 2 &&
    Math.abs(predicted.width) >= SWIPE_FLICK &&
    Math.sign(predicted.width) === Math.sign(dx);
  if (!long && !flung) return null;
  const towardStart = rightToLeft ? dx < 0 : dx > 0;
  return towardStart ? "back" : "forward";
}
