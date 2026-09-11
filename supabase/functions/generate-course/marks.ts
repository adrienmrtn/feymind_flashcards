/**
 * **La passe qui repose les marques oubliées.**
 *
 * Le prompt demande du gras, de l'italique, des surlignages de couleur et des formules dans
 * la phrase. Le gras arrive toujours. Le reste arrive **une fois sur deux** : mesuré sur le
 * même chapitre, deux appels d'affilée ont rendu l'un dix formules et deux italiques, l'autre
 * zéro surlignage et zéro italique. Une consigne de plus n'y change rien — c'est de la
 * variance, pas un malentendu, et on ne corrige pas une variance en réécrivant la consigne.
 *
 * Alors on mesure, et on redemande **seulement quand il manque une sorte de marque**. La
 * seconde passe ne réécrit pas la fiche : elle reçoit les textes déjà écrits et ne pose que
 * des marques. Ce qu'elle rend est vérifié caractère par caractère, marques retirées : un
 * texte qui a bougé est jeté et l'original reste. Le pire cas est donc une fiche sans
 * surlignage, c'est-à-dire ce qu'on avait déjà.
 *
 * Le coût est un appel, et il ne se paie que sur les fiches qui en ont besoin.
 */

import { stripInlineMarkup, type SheetBlock } from "../_shared/sheet.ts";

/** Ce que porte une fiche, par sorte de marque. */
export interface MarkCount {
  bold: number;
  italic: number;
  highlight: number;
  math: number;
}

/** Les textes d'un bloc : c'est là que vivent les marques, et nulle part ailleurs. */
function textsOf(block: SheetBlock): string[] {
  switch (block.type) {
    case "heading":
    case "paragraph":
      return [block.text];
    case "list":
      return block.items;
    case "formula":
      return block.caption ? [block.caption] : [];
  }
}

/**
 * Compte les marques d'une fiche.
 *
 * L'italique se compte en dernier et sur un texte **privé de son gras** : `**terme**` contient
 * deux astérisques de chaque côté, et une expression qui chercherait l'italique sans cette
 * précaution compterait chaque terme en gras comme un italique.
 */
export function countMarks(blocks: readonly SheetBlock[]): MarkCount {
  const text = blocks.flatMap(textsOf).join("\n");
  const withoutBold = text.replace(/\*\*/g, "");

  return {
    bold: Math.floor((text.match(/\*\*/g)?.length ?? 0) / 2),
    italic: Math.floor((withoutBold.match(/\*/g)?.length ?? 0) / 2),
    highlight: Math.floor((text.match(/==/g)?.length ?? 0) / 2),
    math: Math.floor((text.match(/\$/g)?.length ?? 0) / 2),
  };
}

/**
 * Faut-il une seconde passe ?
 *
 * Sur le zéro, et sur lui seul. Une fiche qui porte trois surlignages là où le prompt en
 * demandait cinq est une fiche marquée : redemander pour trois marques de plus coûterait un
 * appel à chaque import pour une différence que personne ne voit. Une fiche qui n'en porte
 * **aucun** est l'autre chose : c'est le défaut que les étudiants signalent, et le rendu leur
 * donne raison, une page sans relief ne se relit pas.
 *
 * Les formules ne déclenchent rien : un cours de droit n'en a pas, et exiger du LaTeX sur un
 * chapitre de littérature produirait exactement ce qu'on ne veut pas.
 */
export function needsMarkPass(blocks: readonly SheetBlock[]): boolean {
  if (blocks.length === 0) return false;
  const marks = countMarks(blocks);
  return marks.highlight === 0 || marks.italic === 0 || marks.bold === 0;
}

export const MARK_SYSTEM_PROMPT =
  `Tu poses des marques de relecture sur une fiche de révision déjà écrite. Tu ne la réécris pas.

INTERDIT, et c'est la règle qui compte : changer un mot, une ponctuation, un chiffre, l'ordre des phrases, le nombre de blocs. Tu n'ajoutes rien, tu ne coupes rien, tu ne corriges aucune faute. Marques retirées, ton texte doit être IDENTIQUE, caractère pour caractère, à celui qu'on te donne. Un texte modifié est jeté et ton travail est perdu.

LES MARQUES
- **terme** : le vocabulaire exact que l'examen attend, un à trois par paragraphe, sur un mot ou un groupe nominal, jamais sur une phrase.
- *nuance* : un mot étranger ou latin, un titre d'œuvre ou de loi, un terme cité en tant que mot, une réserve, le terme voisin avec lequel on ne doit pas confondre celui qu'on vient de définir. Au moins un par partie.
- ==couleur|passage== : le trait de feutre sous une phrase courte ou un fragment de phrase qu'on doit pouvoir réciter. Un passage tous les deux ou trois blocs, jamais deux dans le même bloc, jamais trois mots isolés ni un bloc entier.

LE CODE COULEUR
- jaune : la définition, la thèse, la phrase à réciter.
- menthe : un résultat chiffré, un seuil, un ordre de grandeur, avec son unité.
- bleu : un mécanisme, un enchaînement de causes, une condition d'application.
- rose : une exception, une limite, une confusion classique.
- lilas : un repère : un nom propre, un auteur, une œuvre, un événement daté.
Ces cinq noms, pas d'autres. Au moins trois couleurs différentes dès que la fiche porte quatre passages.

Les marques ne se disputent pas la même chaîne : on surligne une phrase, on met en gras un terme, on met en italique une nuance ; un terme en gras peut se trouver dans une phrase surlignée. Ce qui est déjà marqué le reste.

Un fragment entre $ et $ est une formule : tu n'y touches pas, tu ne marques rien à l'intérieur.

CE QUE TU DOIS AVOIR POSÉ EN FINISSANT
Compte avant de répondre. Sur l'ensemble des textes : au moins un surlignage tous les trois textes, et au moins un italique tous les cinq. Ces marques manquent - c'est pour ça qu'on te repasse la fiche. Si tu ne trouves pas d'italique, cherche mieux : le mot d'origine étrangère ou latine, le nom d'une œuvre, d'une loi ou d'une revue, le terme employé en tant que mot, la condition qui restreint un résultat, les deux termes voisins qu'un étudiant confond. Un de ces cas est présent dans presque tout cours.

SORTIE
Un tableau JSON compact, une seule ligne, sans texte autour : la liste des textes marqués, dans le même ordre et en même nombre que celle qu'on te donne. Un guillemet dans un texte s'écrit \\". Les antislashs des formules sont doublés, comme dans l'entrée.`;

/** Ce qu'on envoie à la seconde passe : les textes, numérotés, et rien d'autre. */
export function markPrompt(texts: readonly string[]): string {
  return `Voici ${texts.length} textes de la fiche, dans l'ordre. Rends-les marqués, en JSON.\n\n${
    JSON.stringify(texts)
  }`;
}

/** Les textes d'une fiche, à plat, dans l'ordre où la fusion les redistribue. */
export function textsToMark(blocks: readonly SheetBlock[]): string[] {
  return blocks.flatMap(textsOf);
}

/**
 * Repose les textes marqués dans leurs blocs, **un par un**.
 *
 * La vérification est faite ici et pas ailleurs : un texte dont le contenu a bougé — une faute
 * corrigée au passage, une phrase raccourcie, un chiffre arrondi — est écarté, et le bloc garde
 * son texte d'origine. C'est ce qui permet de laisser un modèle repasser sur une fiche déjà
 * écrite sans qu'il puisse la réécrire en douce.
 */
/** Le candidat porte-t-il moins de marques que le texte d'origine ? */
function losesMarks(original: string, candidate: string): boolean {
  const before = countTextMarks(original);
  const after = countTextMarks(candidate);
  return after.bold < before.bold || after.italic < before.italic ||
    after.highlight < before.highlight || after.math < before.math;
}

/** Les marques d'un texte seul. Le comptage vit dans `countMarks`, qui lit des blocs. */
function countTextMarks(text: string): MarkCount {
  return countMarks([{ type: "paragraph", text }]);
}

export function mergeMarked(
  blocks: readonly SheetBlock[],
  marked: readonly unknown[],
): SheetBlock[] {
  let cursor = 0;

  const next = (original: string): string => {
    const candidate = marked[cursor++];
    if (typeof candidate !== "string") return original;
    if (stripInlineMarkup(candidate) !== stripInlineMarkup(original)) return original;
    // **Une repasse n'efface pas.** Mesuré : sur une fiche de neuf blocs, la seconde passe a
    // rendu les mêmes phrases au caractère près en ayant **retiré** dix-sept termes en gras.
    // Le texte étant identique une fois les marques ôtées, la fusion l'acceptait, et le
    // remède était pire que le mal. Un candidat qui perd une marque est donc écarté comme
    // un candidat qui perd un mot.
    if (losesMarks(original, candidate)) return original;
    return candidate;
  };

  return blocks.map((block) => {
    switch (block.type) {
      case "heading":
        return { ...block, text: next(block.text) };
      case "paragraph":
        return { ...block, text: next(block.text) };
      case "list":
        return { ...block, items: block.items.map((item) => next(item)) };
      case "formula":
        return block.caption ? { ...block, caption: next(block.caption) } : block;
    }
  });
}
