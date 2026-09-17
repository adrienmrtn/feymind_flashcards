import type { SheetBlock } from "@micabo/core";

import { stripInlineMarkup } from "@micabo/core";

/**
 * **Un chapitre : un titre de partie, et tout ce qui le suit.**
 *
 * Jumeau de `Micabo/Models/SheetChapters.swift`. La fiche est, et reste, une liste plate de
 * blocs : c'est ce que le modèle écrit, ce que la base garde et ce que les deux clients
 * lisent. Le chapitre n'est pas un niveau de plus dans le modèle, c'est une lecture de cette
 * liste faite au moment de l'afficher — ajouter un conteneur aurait demandé de migrer les
 * fiches en base pour une information que les blocs portent déjà.
 */
export interface SheetChapter {
  /**
   * Le rang du chapitre, à partir de zéro.
   *
   * C'est lui qui fait l'identité, et pas le titre : deux parties d'un même cours peuvent
   * s'appeler « Applications », et une clé de rendu qui les confondrait replierait les deux
   * ensemble.
   */
  index: number;
  /**
   * Le titre, **sans son balisage**, pour l'en-tête de l'accordéon et le sommaire.
   *
   * `null` avant le premier titre de partie : une fiche ouvre sur un paragraphe, jamais sur
   * un titre, et ce qui précède la première partie n'est pas une partie.
   */
  title: string | null;
  /**
   * Les blocs du chapitre, **titre compris**.
   *
   * Le titre reste dans le texte au lieu de monter dans l'en-tête, et c'est ce qui permet de
   * continuer à le corriger comme le reste : la fiche est un document qu'on écrit, et un
   * titre qui ne vivrait plus que dans un en-tête deviendrait la seule ligne de la page
   * qu'on ne peut plus toucher.
   */
  blocks: SheetBlock[];
}

/**
 * Découpe une fiche à chaque titre de partie.
 *
 * Un titre de sous-partie n'ouvre pas de chapitre : c'est le plan **dans** une partie, et
 * replier à ce niveau donnerait vingt accordéons d'une ligne au lieu du plan qu'on cherche.
 */
export function splitChapters(blocks: readonly SheetBlock[]): SheetChapter[] {
  const chapters: SheetChapter[] = [];
  let current: SheetBlock[] = [];
  let title: string | null = null;

  const close = () => {
    if (current.length === 0) return;
    chapters.push({ index: chapters.length, title, blocks: current });
    current = [];
  };

  for (const block of blocks) {
    if (block.type === "heading" && block.level === 1) {
      // On ferme **avant** de retenir le nouveau titre : celui qu'on ferme est encore celui
      // du chapitre qui s'achève.
      close();
      title = stripInlineMarkup(block.text).trim() || null;
    }
    current.push(block);
  }
  close();

  return chapters;
}

/**
 * Recolle les chapitres en une fiche.
 *
 * L'inverse exact de `splitChapters` : `joinChapters(splitChapters(blocks))` rend `blocks`,
 * toujours, y compris pour une fiche sans le moindre titre. C'est la propriété dont dépend
 * l'enregistrement — un chapitre se modifie seul, et la fiche entière se réécrit à partir
 * des autres.
 */
export function joinChapters(chapters: readonly SheetChapter[]): SheetBlock[] {
  return chapters.flatMap((chapter) => chapter.blocks);
}

/**
 * Remplace les blocs d'un chapitre et rend la fiche entière.
 *
 * Un rang inconnu ne fait rien : mieux vaut perdre une frappe que réécrire la fiche à partir
 * d'un chapitre qui n'existe plus.
 */
export function replaceChapter(
  chapters: readonly SheetChapter[],
  index: number,
  blocks: SheetBlock[],
): SheetBlock[] {
  if (index < 0 || index >= chapters.length) return joinChapters(chapters);
  return joinChapters(
    chapters.map((chapter) => (chapter.index === index ? { ...chapter, blocks } : chapter)),
  );
}
