import type { SheetHighlight } from "@micabo/core";

/**
 * Poser et retirer une marque sur ce qui est sélectionné.
 *
 * `document.execCommand` ferait ça en une ligne, et c'est bien pourquoi tout le monde
 * l'utilise encore. Deux raisons de ne pas s'en servir ici : il est déprécié depuis dix ans
 * et son rendu diffère d'un navigateur à l'autre (`<b>` ici, `<span style>` là), ce qui
 * remonterait jusqu'à la fiche enregistrée ; et il ne sait pas poser un surlignage de
 * couleur, qui est la moitié de ce qu'on demande.
 *
 * Le procédé tient en trois temps, et c'est le seul qui soit prévisible : on ramasse les
 * nœuds de texte que la sélection touche, on les **coupe** à ses bornes pour ne travailler
 * que sur ce qui est réellement sélectionné, puis on enveloppe - ou on déballe si tout est
 * déjà marqué, parce qu'un bouton de mise en forme doit faire l'aller comme le retour.
 */

export type Mark = "bold" | "italic";

const TAGS: Record<Mark, string> = { bold: "STRONG", italic: "EM" };
const ALIASES: Record<Mark, string[]> = { bold: ["STRONG", "B"], italic: ["EM", "I"] };

export function toggleMark(root: HTMLElement, mark: Mark): boolean {
  return applyToSelection(root, {
    matches: (element) => ALIASES[mark].includes(element.tagName),
    wrap: () => document.createElement(TAGS[mark]),
  });
}

/**
 * Le surligneur. Il **remplace** la couleur au lieu de l'empiler : cliquer sur menthe alors
 * qu'on est sur du jaune donne de la menthe, et re-cliquer sur la couleur déjà posée retire
 * la marque. C'est le comportement d'un feutre qu'on repasse.
 */
export function toggleHighlight(root: HTMLElement, color: SheetHighlight): boolean {
  return applyToSelection(root, {
    matches: (element) => element.tagName === "MARK" && element.dataset.hl === color,
    replaces: (element) => element.tagName === "MARK",
    wrap: () => {
      const mark = document.createElement("mark");
      mark.dataset.hl = color;
      return mark;
    },
  });
}

function applyToSelection(
  root: HTMLElement,
  rule: {
    matches: (element: HTMLElement) => boolean;
    replaces?: (element: HTMLElement) => boolean;
    wrap: () => HTMLElement;
  },
): boolean {
  const selection = window.getSelection();
  if (!selection || selection.rangeCount === 0) return false;
  const range = selection.getRangeAt(0);
  if (range.collapsed || !root.contains(range.commonAncestorContainer)) return false;

  const nodes = splitAtBoundaries(root, range);
  if (nodes.length === 0) return false;

  // Tout est déjà marqué : le bouton retire. Sinon il pose, y compris sur ce qui l'était
  // déjà à moitié - c'est ce qu'on attend en repassant un feutre sur un mot déjà souligné.
  const marked = nodes.every((node) => ancestorMatching(node, root, rule.matches) !== null);

  for (const node of nodes) {
    const existing = ancestorMatching(node, root, rule.matches);
    if (marked && existing) {
      unwrap(existing);
      continue;
    }
    if (marked) continue;
    const replaced = rule.replaces ? ancestorMatching(node, root, rule.replaces) : null;
    if (replaced) unwrap(replaced);
    if (ancestorMatching(node, root, rule.matches)) continue;
    const wrapper = rule.wrap();
    node.parentNode?.insertBefore(wrapper, node);
    wrapper.appendChild(node);
  }

  root.normalize();
  return true;
}

/**
 * Les nœuds de texte que la sélection touche, coupés à ses bornes.
 *
 * Sans la coupe, marquer trois mots au milieu d'une phrase marquerait la phrase entière : le
 * nœud de texte est le même. On casse donc le premier et le dernier en deux, et on ne rend
 * que le morceau qui est dans la sélection.
 */
function splitAtBoundaries(root: HTMLElement, range: Range): Text[] {
  const start = range.startContainer;
  const end = range.endContainer;

  if (end.nodeType === Node.TEXT_NODE && range.endOffset < (end.textContent?.length ?? 0)) {
    (end as Text).splitText(range.endOffset);
  }
  if (start.nodeType === Node.TEXT_NODE && range.startOffset > 0) {
    const tail = (start as Text).splitText(range.startOffset);
    range.setStart(tail, 0);
  }

  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  const found: Text[] = [];
  let node = walker.nextNode();
  while (node) {
    const text = node as Text;
    if ((text.textContent ?? "").length > 0 && range.intersectsNode(text)) {
      // `intersectsNode` compte aussi un nœud qui touche la borne sans être dedans.
      const inside = document.createRange();
      inside.selectNodeContents(text);
      const overlaps =
        range.compareBoundaryPoints(Range.END_TO_START, inside) < 0 &&
        range.compareBoundaryPoints(Range.START_TO_END, inside) > 0;
      if (overlaps) found.push(text);
    }
    node = walker.nextNode();
  }
  return found;
}

function ancestorMatching(
  node: Node,
  root: HTMLElement,
  matches: (element: HTMLElement) => boolean,
): HTMLElement | null {
  let current = node.parentElement;
  while (current && current !== root) {
    if (matches(current)) return current;
    current = current.parentElement;
  }
  return null;
}

function unwrap(element: HTMLElement): void {
  const parent = element.parentNode;
  if (!parent) return;
  while (element.firstChild) parent.insertBefore(element.firstChild, element);
  parent.removeChild(element);
}

/** Le bloc qui porte le curseur, pour la liste des styles. */
export function currentBlock(root: HTMLElement): HTMLElement | null {
  const selection = window.getSelection();
  if (!selection || selection.rangeCount === 0) return null;
  let node: Node | null = selection.getRangeAt(0).startContainer;
  while (node && node.parentElement && node.parentElement !== root) {
    node = node.parentElement;
  }
  return node instanceof HTMLElement ? node : (node?.parentElement ?? null);
}
