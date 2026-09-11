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
import { cleanMarks, emptyShapeReport, type ShapeReport } from "./mark-shape.ts";

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
 * **Combien de marques une fiche devrait porter**, en caractères et non en blocs.
 *
 * « Un à trois termes en gras par paragraphe » ne veut rien dire quand un paragraphe fait six
 * cents caractères : sur un mémo d'investissement, la fiche portait un seul gras par pavé, ce
 * qui se lit exactement comme une page sans gras. Un paragraphe de fiche de cours en fait
 * cent cinquante ; le même prompt donne donc quatre fois moins de relief sur un document long,
 * et c'est invisible tant qu'on ne mesure que des documents courts.
 *
 * Les seuils sont donc des **densités**. Ils valent pour une fiche de dix blocs comme pour une
 * de quatre-vingt-dix.
 */
export const CHARS_PER = {
  /** Un terme en gras tous les deux cent cinquante caractères, soit un ou deux par paragraphe. */
  bold: 250,
  /** Un passage surligné tous les huit cents caractères : un par paragraphe long. */
  highlight: 800,
  /** Une nuance en italique tous les deux mille caractères. C'est rare, et ça doit l'être. */
  italic: 2_000,
} as const;

/** Ce qu'on attend d'un lot de textes, arrondi, jamais zéro. */
export function markTargets(texts: readonly string[]): MarkCount {
  const chars = texts.reduce((total, text) => total + text.length, 0);
  return {
    bold: Math.max(1, Math.round(chars / CHARS_PER.bold)),
    highlight: Math.max(1, Math.round(chars / CHARS_PER.highlight)),
    italic: Math.max(1, Math.round(chars / CHARS_PER.italic)),
    math: 0,
  };
}

/**
 * Faut-il une seconde passe ?
 *
 * Quand la fiche porte **moins de la moitié** de ce que sa longueur appelle. Le déclenchement
 * était sur le zéro absolu : une fiche de dix-huit mille caractères avec vingt-quatre gras et
 * deux surlignages y échappait, alors que c'est précisément la page sans relief que l'étudiant
 * signale. La moitié plutôt que le compte plein, parce qu'une fiche déjà correctement marquée
 * ne doit pas payer un appel de plus pour trois marques.
 *
 * Les formules ne déclenchent rien : un cours de droit n'en a pas, et exiger du LaTeX sur un
 * chapitre de littérature produirait exactement ce qu'on ne veut pas.
 */
export function needsMarkPass(blocks: readonly SheetBlock[]): boolean {
  if (blocks.length === 0) return false;
  const texts = textsToMark(blocks);
  const marks = countMarks(blocks);
  const target = markTargets(texts);
  return marks.bold * 2 < target.bold ||
    marks.highlight * 2 < target.highlight ||
    marks.italic * 2 < target.italic;
}

/**
 * Les textes, par petits paquets.
 *
 * Quarante-cinq textes de six cents caractères à réémettre dans un seul JSON, c'est huit mille
 * jetons de sortie : la limite exacte du modèle. La fiche qui a motivé ce découpage est sortie
 * avec deux marques posées de travers et rien d'autre - une réponse tronquée ne dit pas
 * qu'elle l'est, elle rend juste du JSON pauvre. Six textes par lot laissent de la marge, et
 * les lots partent ensemble. Court, le lot garde aussi l'attention du modèle : à quinze
 * textes, il lisait la consigne, rendait les textes inchangés, et la fiche restait nue.
 */
export const BATCH_SIZE = 6;

export function batched<T>(items: readonly T[], size = BATCH_SIZE): T[][] {
  const lots: T[][] = [];
  for (let index = 0; index < items.length; index += size) {
    lots.push(items.slice(index, index + size));
  }
  return lots;
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

LA POSE
Une marque s'ouvre au début d'un mot et se ferme à la fin d'un mot. Jamais au milieu : « issue de==rose| 35 ans » est faux, il fallait « issue de ==rose|35 ans de recherche== ». Une marque ouverte se ferme dans le MÊME texte. Un surlignage couvre une phrase courte ou un fragment, deux cent quarante caractères au plus ; un gras couvre un terme, quatre-vingt-dix au plus. Une marque mal posée est retirée à l'arrivée : elle est perdue pour tout le monde.

CE QUE TU DOIS AVOIR POSÉ EN FINISSANT
Compte avant de répondre : le message qui accompagne les textes donne le nombre exact de marques attendues pour ce lot, et c'est un minimum. Ces marques manquent - c'est pour ça qu'on te repasse la fiche. Si tu ne trouves pas d'italique, cherche mieux : le mot d'origine étrangère ou latine, le nom d'une œuvre, d'une loi ou d'une revue, le terme employé en tant que mot, la condition qui restreint un résultat, les deux termes voisins qu'un étudiant confond. Un de ces cas est présent dans presque tout cours.

UN TEXTE RENDU À L'IDENTIQUE EST UNE ERREUR
Tu ne relis pas pour valider : tu marques. Chaque texte qu'on te donne ressort avec au moins une marque de plus qu'à l'entrée, sauf s'il fait moins de cent caractères. Rendre la liste telle qu'elle est arrivée est le seul échec possible de cette tâche.

EXEMPLE
Entrée :
["Nordwind Energy conçoit des batteries thermiques industrielles qui stockent l'électricité excédentaire sous forme de chaleur. Le rendement de conversion atteint 92 pour cent en régime nominal, contre 86 pour cent en régime modulé."]
Sortie :
["Nordwind Energy conçoit des **batteries thermiques industrielles** qui stockent l'électricité excédentaire sous forme de chaleur. ==menthe|Le rendement de conversion atteint 92 pour cent en régime nominal==, contre 86 pour cent en régime *modulé*."]

SORTIE
Un tableau JSON compact, une seule ligne, sans texte autour : la liste des textes marqués, dans le même ordre et en même nombre que celle qu'on te donne. Un guillemet dans un texte s'écrit \\". Les antislashs des formules sont doublés, comme dans l'entrée.`;

/**
 * Ce qu'on envoie à la seconde passe : les textes, et le compte attendu **pour ce lot-là**.
 *
 * Le compte est calculé sur la longueur réelle des textes, pas récité depuis une règle
 * générale. Un modèle à qui l'on dit « pose au moins six termes en gras dans ces huit textes »
 * les pose ; le même, à qui l'on dit « un à trois par paragraphe », en pose un et passe au
 * suivant.
 */
export function markPrompt(texts: readonly string[]): string {
  const target = markTargets(texts);
  const chars = texts.reduce((total, text) => total + text.length, 0);
  return `Voici ${texts.length} textes de la fiche, dans l'ordre, ${chars} caractères en tout.

À poser sur ce lot, au minimum : ${target.bold} termes en **gras**, ${target.highlight} passages ==surlignés== et ${target.italic} passages en *italique*. Rends les mêmes textes, marqués, en JSON.

${JSON.stringify(texts)}`;
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

/**
 * Ce que la fusion a accepté, et ce qu'elle a refusé.
 *
 * Sans ce compte, une repasse qui ne change rien ne se distingue pas d'une repasse dont tous
 * les textes sont refusés : les deux rendent la fiche d'avant. C'est exactement l'ambiguïté
 * qui a coûté deux déploiements.
 */
export interface MergeReport {
  /** Textes remplacés par leur version marquée. */
  changed: number;
  /** Textes identiques à l'entrée : le modèle n'a rien posé dessus. */
  same: number;
  /** Refusés parce que le texte nu avait bougé. */
  moved: number;
  /** Refusés parce qu'une marque y avait disparu. */
  lost: number;
  /** Refusés parce que la réponse n'était pas une chaîne. */
  absent: number;
}

export function emptyMergeReport(): MergeReport {
  return { changed: 0, same: 0, moved: 0, lost: 0, absent: 0 };
}

export function mergeMarked(
  blocks: readonly SheetBlock[],
  marked: readonly unknown[],
  report: MergeReport = emptyMergeReport(),
): SheetBlock[] {
  let cursor = 0;

  const next = (original: string): string => {
    const candidate = marked[cursor++];
    if (typeof candidate !== "string") {
      report.absent += 1;
      return original;
    }
    if (candidate === original) {
      report.same += 1;
      return original;
    }
    if (stripInlineMarkup(candidate) !== stripInlineMarkup(original)) {
      report.moved += 1;
      return original;
    }
    // **Une repasse n'efface pas.** Mesuré : sur une fiche de neuf blocs, la seconde passe a
    // rendu les mêmes phrases au caractère près en ayant **retiré** dix-sept termes en gras.
    // Le texte étant identique une fois les marques ôtées, la fusion l'acceptait, et le
    // remède était pire que le mal. Un candidat qui perd une marque est donc écarté comme
    // un candidat qui perd un mot.
    if (losesMarks(original, candidate)) {
      report.lost += 1;
      return original;
    }
    report.changed += 1;
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

/**
 * Retire les marques mal posées de toute une fiche.
 *
 * Appliqué aux **deux** passes : celle qui écrit la fiche pose parfois un surligneur au milieu
 * d'un mot, exactement comme celle qui la repasse. Voir `mark-shape.ts` pour ce qui est jugé.
 */
export function cleanBlockMarks(
  blocks: readonly SheetBlock[],
  report: ShapeReport = emptyShapeReport(),
): SheetBlock[] {
  const clean = (text: string) => cleanMarks(text, report);
  return blocks.map((block) => {
    switch (block.type) {
      case "heading":
        return { ...block, text: clean(block.text) };
      case "paragraph":
        return { ...block, text: clean(block.text) };
      case "list":
        return { ...block, items: block.items.map(clean) };
      case "formula":
        return block.caption ? { ...block, caption: clean(block.caption) } : block;
    }
  });
}

export { emptyShapeReport, type ShapeReport };

/**
 * Les textes marqués, quelle que soit la forme que le modèle leur a donnée.
 *
 * Mesuré : un lot sur deux revient en objets - `[{"id":1,"texte":"..."}]` - ou enveloppé dans
 * une propriété. La fusion n'y voyait que des candidats « absents » et gardait tout l'original,
 * donc la repasse ne changeait rien sans que rien ne le dise. On accepte donc les trois formes
 * et on refuse le reste.
 */
export function readMarkedTexts(parsed: unknown, expected: number): string[] | null {
  const array = Array.isArray(parsed) ? parsed : unwrapArray(parsed);
  if (!array || array.length !== expected) return null;

  const texts = array.map((entry) => {
    if (typeof entry === "string") return entry;
    if (entry && typeof entry === "object") {
      const record = entry as Record<string, unknown>;
      for (const key of ["texte", "text", "marked", "value", "contenu"]) {
        const found = record[key];
        if (typeof found === "string") return found;
      }
    }
    return null;
  });

  return texts.every((text): text is string => text !== null) ? texts : null;
}

/** Un tableau caché sous une propriété unique : `{"textes": [...]}`. */
function unwrapArray(parsed: unknown): unknown[] | null {
  if (!parsed || typeof parsed !== "object") return null;
  const values = Object.values(parsed as Record<string, unknown>);
  const arrays = values.filter(Array.isArray);
  return arrays.length === 1 ? arrays[0] as unknown[] : null;
}
