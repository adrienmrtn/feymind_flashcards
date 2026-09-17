/**
 * **La passe qui repose les marques oubliées.**
 *
 * Le prompt demande du gras, de l'italique, des surlignages de couleur et des formules dans
 * la phrase. Le gras arrive toujours. Le reste arrive **une fois sur deux** : mesuré sur le
 * même chapitre, deux appels d'affilée ont rendu l'un dix formules et deux italiques, l'autre
 * zéro surlignage et zéro italique. Une consigne de plus n'y change rien — c'est de la
 * variance, pas un malentendu, et on ne corrige pas une variance en réécrivant la consigne.
 *
 * Alors on mesure, et on redemande **seulement quand il manque une sorte de marque**.
 *
 * ## Le modèle désigne, il n'écrit pas
 *
 * La passe rendait d'abord les textes marqués : on lui envoyait la fiche, elle renvoyait la
 * même fiche avec des marqueurs en plus. Deux défauts, et le second se payait tous les jours.
 *
 * Le premier est une question de sûreté. Un modèle qui tient la plume sur un texte déjà validé
 * le corrige au passage : une faute réparée, un chiffre arrondi, dix-sept termes en gras
 * effacés sur une fiche de neuf blocs. Il fallait donc comparer les textes caractère par
 * caractère à l'arrivée, et jeter le lot entier au moindre écart — donc jeter aussi les bonnes
 * marques qu'il portait.
 *
 * Le second est une question de prix. Réémettre la fiche pour y glisser quinze marqueurs, c'est
 * payer en jetons de sortie, les plus chers, un texte que le serveur a déjà sous la main.
 * Mesuré sur une fiche courante : deux mille neuf cents jetons de sortie pour une quinzaine de
 * marques.
 *
 * La passe rend donc maintenant **la liste des marques à poser** : le numéro du texte, la sorte
 * de marque, et le passage recopié. Le serveur le retrouve dans le texte et pose les marqueurs
 * lui-même. Le modèle ne touche plus au texte, donc il ne peut plus l'abîmer : la vérification
 * n'est plus un filet, elle est devenue inutile. Et la sortie tombe à quelques centaines de
 * jetons, ce qui rend au passage les gros lots possibles (voir `LOT_LIMITS`).
 *
 * Ce qui reste à vérifier n'est plus le texte mais **le passage** : présent une seule fois,
 * posé au bord d'un mot, d'une longueur plausible, hors des formules et sans croiser une marque
 * déjà là. Tout est dans `mark-shape.ts`, et un passage refusé ne coûte qu'une marque.
 *
 * ## Et elle ne demande que ce qui manque, qu'à qui peut le porter
 *
 * Le déclenchement se décide sur la fiche entière, mais le manque est local et il a une sorte.
 * La passe envoyait pourtant tous les textes - titres et points de liste compris, trop courts
 * pour porter quoi que ce soit - en réclamant les trois sortes de marques, y compris celles qui
 * ne manquaient pas. Une fiche à qui il ne manquait que des italiques se faisait rejuger tout
 * son gras.
 *
 * `planMarkPass` tranche les deux : quelles sortes manquent, et lesquels des textes ont la place
 * d'en accueillir une. Mesuré sur une fiche courante, dix-huit textes partent au lieu de
 * trente-quatre, en un appel au lieu de deux. Et quand rien n'a la place - une fiche qui n'est
 * faite que de titres et de listes courtes - l'appel ne part pas du tout.
 */

import { SHEET_HIGHLIGHTS, type SheetBlock } from "../_shared/sheet.ts";
import {
  cleanMarks,
  closerFor,
  emptyShapeReport,
  markedRanges,
  type MarkedRange,
  type MarkKind,
  openerFor,
  placeable,
  type ShapeReport,
} from "./mark-shape.ts";

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
  /**
   * Un passage surligné tous les mille deux cents caractères.
   *
   * C'était huit cents, soit un par paragraphe : une fiche de douze mille caractères visait
   * quinze bandes, et comme chacune pouvait courir sur six lignes, près d'un tiers de la page
   * finissait en aplat. Une page entièrement surlignée ne met rien en avant - c'est le défaut
   * qu'on corrige, et il se corrige des deux côtés : moins de bandes ici, des bandes plus
   * courtes dans `mark-shape.ts`.
   */
  highlight: 1_200,
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

/** Les textes d'une fiche, à plat, dans l'ordre où la pose les redistribue. */
export function textsToMark(blocks: readonly SheetBlock[]): string[] {
  return blocks.flatMap(textsOf);
}

/** Les sortes de marques qui manquent à une fiche. */
export interface MarkWish {
  bold: boolean;
  highlight: boolean;
  italic: boolean;
}

/** Un texte retenu pour la repasse, et son rang dans la fiche. */
export interface MarkCandidate {
  index: number;
  text: string;
}

/** Ce que la repasse doit demander : à quels textes, et quelles marques. */
export interface MarkPlan {
  candidates: MarkCandidate[];
  wish: MarkWish;
}

/**
 * En dessous, un texte n'accueille pas de marque.
 *
 * Un titre de partie fait quarante caractères, un point de liste soixante. Le surligneur en
 * demande douze au minimum et couvre « une phrase courte ou un fragment » : sur une ligne de
 * cette taille, il couvre la ligne, ce qui ne met rien en avant. Le gras y tiendrait, mais un
 * titre est déjà distinct sans lui.
 */
const MIN_MARKABLE = 100;

/**
 * **Quelles sortes de marques manquent**, sur la fiche entière.
 *
 * Le seuil est celui d'avant, la moitié de la cible, mais son résultat n'est plus écrasé par
 * un `ou` : on retient *lesquelles* manquent, parce que c'est ce que la consigne du lot va
 * nommer. Une fiche à qui il ne manque que des italiques se faisait jusqu'ici rejuger tout
 * son gras.
 */
function wishFor(blocks: readonly SheetBlock[]): MarkWish {
  const marks = countMarks(blocks);
  const target = markTargets(textsToMark(blocks));
  return {
    bold: marks.bold * 2 < target.bold,
    highlight: marks.highlight * 2 < target.highlight,
    italic: marks.italic * 2 < target.italic,
  };
}

/**
 * **Ce texte-ci a-t-il de la place pour une des marques qui manquent ?**
 *
 * Le déclenchement se décide sur la fiche, mais le manque, lui, est local : une fiche bien
 * marquée dans sa première moitié et nue dans la seconde envoyait quand même ses quarante-deux
 * textes, titres et points de liste compris, dont vingt-deux trop courts pour porter quoi que
 * ce soit. On payait leur place dans la consigne, et le modèle y cherchait des marques qui
 * n'avaient nulle part où se poser.
 *
 * Le gras et le surligneur se jugent sur la densité du texte lui-même : c'est ce que le prompt
 * d'écriture demande, un gras tous les deux cent cinquante caractères, un surlignage tous les
 * huit cents. L'italique, non - il se compte sur la fiche entière, et un paragraphe de six
 * cents caractères n'en « mérite » que trois dixièmes. À ce compte-là aucun texte ne serait
 * jamais candidat, et la marque la plus souvent absente ne serait jamais reposée. Tout texte
 * qui n'en porte pas peut en accueillir un.
 */
function hasRoom(text: string, wish: MarkWish): boolean {
  if (text.length < MIN_MARKABLE) return false;

  const own = countMarks([{ type: "paragraph", text }]);
  if (wish.bold && own.bold < Math.round(text.length / CHARS_PER.bold)) return true;
  if (wish.highlight && own.highlight < Math.round(text.length / CHARS_PER.highlight)) return true;
  if (wish.italic && own.italic === 0) return true;
  return false;
}

/**
 * Ce que la repasse doit demander, ou `null` s'il n'y a rien à demander.
 *
 * Deux façons de ne rien faire, et elles sont différentes : la fiche est correctement marquée,
 * ou il lui manque des marques mais aucun de ses textes n'a la place d'en porter une - une
 * fiche qui n'est faite que de titres et de listes courtes, par exemple. Dans les deux cas
 * l'appel ne part pas, ce qui est le seul appel dont on soit certain qu'il ne servait à rien.
 */
export function planMarkPass(blocks: readonly SheetBlock[]): MarkPlan | null {
  if (blocks.length === 0) return null;

  const wish = wishFor(blocks);
  if (!wish.bold && !wish.highlight && !wish.italic) return null;

  const candidates: MarkCandidate[] = [];
  textsToMark(blocks).forEach((text, index) => {
    if (hasRoom(text, wish)) candidates.push({ index, text });
  });

  return candidates.length === 0 ? null : { candidates, wish };
}

/** Un lot de textes, et le rang de chacun dans la fiche. */
export interface Lot {
  texts: string[];
  /**
   * Rang de chaque texte du lot dans la fiche, dans le même ordre.
   *
   * Un rang et non un décalage : la sélection saute les textes qui n'ont pas de place pour
   * une marque, donc les rangs d'un lot ne se suivent plus.
   */
  indices: number[];
}

/**
 * **Ce qu'un lot peut contenir.**
 *
 * Les lots faisaient six textes, et pour une raison qui n'existe plus : la passe réémettait
 * les textes, donc quarante-cinq textes de six cents caractères dans un seul JSON valaient
 * huit mille jetons de sortie, la limite exacte du modèle. Une réponse tronquée ne dit pas
 * qu'elle l'est, elle rend juste du JSON pauvre. Six laissaient de la marge.
 *
 * Depuis que la réponse est une liste de marques, sa taille ne suit plus celle des textes
 * mais celle des marques : quelques centaines de jetons quel que soit le lot. Le plafond
 * redevient donc l'**entrée**, et une fiche courante tient en un seul appel au lieu de sept —
 * autant de fois le prompt système de mille jetons qu'on ne paie plus. La sélection de
 * `planMarkPass` y est pour beaucoup : elle n'envoie que la moitié des textes.
 *
 * Vingt-quatre et non « tout », parce que l'autre raison des petits lots tenait, elle, à
 * l'attention : à quinze textes, l'ancienne passe lisait la consigne et recopiait. Cet
 * échec-là était un échec de recopie, et recopier n'est plus la tâche ; reste qu'on ne remonte
 * pas un plafond sur un raisonnement. Ces deux nombres sont à relever après mesure de
 * `placed` et de `absent` sur des fiches réelles, pas avant.
 */
export const LOT_LIMITS = { texts: 24, chars: 12_000 } as const;

export function batched(
  candidates: readonly MarkCandidate[],
  limits: { texts: number; chars: number } = LOT_LIMITS,
): Lot[] {
  const lots: Lot[] = [];
  let texts: string[] = [];
  let indices: number[] = [];
  let chars = 0;

  for (const candidate of candidates) {
    // Un texte seul plus gros que le plafond part quand même : le laisser de côté le perdrait,
    // et un paragraphe de douze mille caractères n'existe pas sur une fiche.
    const full = texts.length >= limits.texts || chars + candidate.text.length > limits.chars;
    if (texts.length > 0 && full) {
      lots.push({ texts, indices });
      texts = [];
      indices = [];
      chars = 0;
    }
    texts.push(candidate.text);
    indices.push(candidate.index);
    chars += candidate.text.length;
  }

  if (texts.length > 0) lots.push({ texts, indices });
  return lots;
}

export const MARK_SYSTEM_PROMPT =
  `Tu relis une fiche de révision déjà écrite et tu dis OÙ poser les marques de relecture. Tu ne réécris rien et tu ne rends aucun texte de fiche : tu rends une liste de marques.

CE QUE TU RENDS
Un tableau JSON compact, une seule ligne, sans texte autour. Un objet par marque à poser :
{"t":0,"m":"gras","q":"le passage exact"}
- "t" : le numéro du texte, celui qui est écrit entre crochets devant lui. Le premier est 0.
- "m" : "gras", "italique", ou le nom d'un surligneur : "jaune", "menthe", "bleu", "rose", "lilas".
- "q" : le passage à marquer, RECOPIÉ DEPUIS LE TEXTE caractère pour caractère, accents, ponctuation et majuscules compris.

LA RÈGLE QUI DÉCIDE DE TOUT : "q" SE RETROUVE DANS SON TEXTE, UNE SEULE FOIS
Le serveur cherche ton passage dans le texte numéroté "t" et pose les marqueurs autour. S'il ne l'y trouve pas, ou s'il l'y trouve deux fois, la marque est perdue et personne ne peut la rattraper.
- Recopie, ne réécris pas de mémoire. Un mot changé, un accent oublié, une apostrophe droite à la place d'une courbe, et le passage est introuvable.
- Si le passage risque d'apparaître ailleurs dans le même texte, rallonge-le d'un mot ou deux jusqu'à ce qu'il soit unique.
- Tu ne corriges rien. Une faute, un chiffre douteux, une tournure lourde : ce n'est pas ton travail, et un texte corrigé n'est plus un texte citable.
- Ne recopie pas dans "q" les marqueurs déjà présents (**, *, ==couleur|). Choisis un passage qui n'en porte pas.
- Un passage commence au début d'un mot et finit à la fin d'un mot. Jamais au milieu.

LES MARQUES
- "gras" : le vocabulaire exact que l'examen attend. Un mot ou un groupe nominal, jamais une phrase. Quatre-vingt-dix caractères au plus.
- "italique" : une nuance. Un mot étranger ou latin, un titre d'œuvre, de loi ou de revue, un terme cité en tant que mot, une réserve qui change le résultat, le terme voisin qu'on ne doit pas confondre avec celui qu'on vient de définir. Soixante-dix caractères au plus.
- un surligneur : le trait de feutre sous une phrase courte ou un fragment qu'on doit pouvoir réciter. Entre douze et CENT QUARANTE caractères, soit trois lignes de téléphone au plus. Pas trois mots isolés, pas un texte entier, et UN SEUL PAR TEXTE : un second est refusé, et deux textes qui se suivent ne peuvent pas en porter chacun un.
- un surligneur COMMENCE UNE PROPOSITION : au début du texte, ou juste après un point, un deux-points, un point-virgule, un point d'interrogation ou d'exclamation. JAMAIS après une virgule ni au milieu d'une phrase. « Cependant, une tendance différente a émergé » mal ouvert donne une bande qui démarre en plein milieu d'une ligne : ça se lit comme une sélection ratée, pas comme un passage retenu. Si le passage que tu vises commence après une virgule, recule jusqu'au début de la phrase, ou choisis un autre passage.

LE CODE COULEUR
Une couleur dit une SORTE d'information, la même d'un bout à l'autre de la fiche.
- jaune : la définition, la thèse, la phrase que l'étudiant devra pouvoir réciter.
- menthe : un résultat chiffré, un seuil, un ordre de grandeur, avec son unité.
- bleu : un mécanisme, un enchaînement de causes, une condition d'application.
- rose : une exception, une limite, une confusion classique, ce qui se rate à l'examen.
- lilas : un repère : un nom propre, un auteur, une œuvre, une loi, un événement daté.
LE JAUNE EST LE FEUTRE PAR DÉFAUT, et une autre couleur ne sort que quand le sens l'impose : un chiffre pour la menthe, une exception pour le rose. Ne cherche pas à varier. Une fiche où les cinq teintes se succèdent n'est pas mieux repérée qu'une fiche d'un seul feutre, elle est seulement plus bruyante.

OÙ NE PAS MARQUER
- Entre $ et $ : c'est une formule, tu n'y touches pas et tu ne marques rien à l'intérieur.
- Sur un passage qui porte déjà une marque : ce qui est marqué le reste.
- À cheval sur une marque existante : ton passage s'ouvre et se ferme dans la même zone non marquée.
- Un gras peut se trouver dans un passage surligné, à condition d'y être ENTIÈREMENT.

CE QUE TU DOIS AVOIR POSÉ EN FINISSANT
Le message qui accompagne les textes dit quelles sortes de marques manquent et combien il en faut sur ce lot, et ces nombres sont un MINIMUM. Il ne nomme que les sortes qui manquent, et c'est la raison pour laquelle on te repasse la fiche.

UNE LISTE VIDE EST UNE ERREUR
Tu ne relis pas pour valider, tu marques. Les textes qu'on te donne ont tous été retenus parce qu'il leur manque une marque : chacun ressort avec au moins une. Rendre un tableau vide est le seul échec possible de cette tâche.

EXEMPLE
Textes :
[0] Nordwind Energy conçoit des batteries thermiques industrielles qui stockent l'électricité excédentaire sous forme de chaleur. Le rendement de conversion atteint 92 pour cent en régime nominal, contre 86 pour cent en régime modulé.
Réponse :
[{"t":0,"m":"gras","q":"batteries thermiques industrielles"},{"t":0,"m":"menthe","q":"Le rendement de conversion atteint 92 pour cent en régime nominal"},{"t":0,"m":"italique","q":"modulé"}]

Réponds uniquement par le tableau JSON.`;

/**
 * Ce qu'on envoie à la seconde passe : les textes numérotés, et le compte attendu **pour ce
 * lot-là**.
 *
 * Le compte est calculé sur la longueur réelle des textes, pas récité depuis une règle
 * générale. Un modèle à qui l'on dit « pose au moins six termes en gras dans ces huit textes »
 * les pose ; le même, à qui l'on dit « un à trois par paragraphe », en pose un et passe au
 * suivant.
 *
 * Les textes sont numérotés en clair plutôt que sérialisés en JSON : le modèle doit renvoyer
 * un numéro de texte, et un crochet devant la ligne se lit mieux qu'un rang implicite dans un
 * tableau. Ça épargne aussi l'échappement, donc quelques jetons par texte.
 */
export function markPrompt(texts: readonly string[], wish: MarkWish): string {
  const target = markTargets(texts);
  const chars = texts.reduce((total, text) => total + text.length, 0);
  const numbered = texts.map((text, index) => `[${index}] ${text}`).join("\n");

  const plural = texts.length > 1 ? "s" : "";

  const asked: string[] = [];
  if (wish.bold) asked.push(agree(target.bold, 'marque "gras"', 'marques "gras"'));
  if (wish.highlight) asked.push(agree(target.highlight, "surligneur", "surligneurs"));
  if (wish.italic) asked.push(agree(target.italic, 'marque "italique"', 'marques "italique"'));

  // Nommer une sorte qui ne manque pas, c'est faire rejuger du gras correct pour obtenir des
  // italiques. La consigne ne parle donc que du déficit, et elle le dit.
  const only = asked.length < 3
    ? " Ce sont les seules sortes qui manquent à cette fiche : n'en pose pas d'autres."
    : "";

  // Cette recherche-là ne sert que si l'italique manque, et elle est longue : ailleurs, elle
  // prend de la place et de l'attention pour une marque dont on ne veut pas.
  const hunt = wish.italic
    ? `\n\nSi tu ne trouves pas d'italique, cherche mieux : le mot d'origine étrangère ou latine, le nom d'une œuvre ou d'une loi, le terme employé en tant que mot, la condition qui restreint un résultat, les deux termes voisins qu'un étudiant confond. Un de ces cas est présent dans presque tout cours.`
    : "";

  return `Voici ${texts.length} texte${plural} de la fiche, numéroté${plural}, ${chars} caractères en tout. Ils ont été retenus parce qu'il leur manque une marque.

À poser sur ce lot, au minimum : ${enumerate(asked)}.${only} Rends la liste JSON des marques, et rien d'autre.${hunt}

${numbered}`;
}

/** « 1 surligneur », « 3 surligneurs ». */
function agree(count: number, singular: string, plural: string): string {
  return `${count} ${count > 1 ? plural : singular}`;
}

/** « a, b et c ». */
function enumerate(items: readonly string[]): string {
  if (items.length <= 1) return items[0] ?? "";
  return `${items.slice(0, -1).join(", ")} et ${items[items.length - 1]}`;
}

/** Une marque à poser : où, laquelle, et sur quel passage. */
export interface MarkAnchor {
  /** Rang du texte visé. Local au lot à la lecture, recollé à la fiche par l'appelant. */
  text: number;
  kind: MarkKind;
  /** La teinte, pour un surligneur. `null` pour le gras et l'italique. */
  colour: string | null;
  /** Le passage à marquer, tel que le modèle l'a recopié. */
  quote: string;
}

/**
 * Ce que la pose a accepté, et ce qu'elle a refusé.
 *
 * Sans ce compte, une passe dont toutes les marques sont refusées ne se distingue pas d'une
 * passe qui n'a rien proposé : les deux rendent la fiche d'avant. C'est exactement l'ambiguïté
 * qui a coûté deux déploiements du temps où la passe rendait des textes.
 *
 * Les raisons sont séparées parce qu'elles appellent des remèdes opposés : beaucoup d'`absent`
 * veut dire que le modèle réécrit au lieu de citer, et c'est la consigne qu'il faut durcir ;
 * beaucoup de `shape`, qu'il vise mal, et ce sont les bornes qu'il faut revoir.
 */
export interface ApplyReport {
  /** Marques effectivement posées sur la fiche. */
  placed: number;
  /** Passage introuvable dans son texte : le modèle a réécrit au lieu de citer. */
  absent: number;
  /** Passage présent plusieurs fois : on ne sait pas laquelle marquer. */
  ambiguous: number;
  /** Numéro de texte hors du lot. */
  stray: number;
  /** Entrée illisible : champ manquant, sorte de marque inconnue. */
  malformed: number;
  /** Refusée par la forme : bord de mot, longueur, formule. */
  shape: number;
  /** Croise une marque déjà posée, ou une autre marque du même lot. */
  crossing: number;
}

export function emptyApplyReport(): ApplyReport {
  return { placed: 0, absent: 0, ambiguous: 0, stray: 0, malformed: 0, shape: 0, crossing: 0 };
}

const KIND_ALIASES: Record<string, MarkKind> = {
  gras: "bold",
  bold: "bold",
  italique: "italic",
  italic: "italic",
  surligneur: "highlight",
  highlight: "highlight",
};

/**
 * Les marques d'une réponse, quelle que soit la forme que le modèle lui a donnée.
 *
 * Mesuré du temps des textes : un lot sur deux revenait enveloppé dans une propriété, ou en
 * objets aux clés françaises. La pose n'y voyait rien et gardait tout l'original, donc la
 * passe ne changeait rien sans que rien ne le dise. On accepte donc les formes voisines, et
 * on compte ce qu'on refuse.
 *
 * `null` veut dire que la réponse entière est illisible - l'appelant la comptera comme un lot
 * perdu. Un tableau vide veut dire que le modèle n'a rien proposé, ce qui est un autre échec
 * et se lit sur `placed`.
 */
export function readAnchors(
  parsed: unknown,
  texts: number,
  report: ApplyReport = emptyApplyReport(),
): MarkAnchor[] | null {
  const array = Array.isArray(parsed) ? parsed : unwrapArray(parsed);
  if (!array) return null;

  const anchors: MarkAnchor[] = [];
  for (const entry of array) {
    const anchor = readAnchor(entry, texts, report);
    if (anchor) anchors.push(anchor);
  }
  return anchors;
}

function readAnchor(entry: unknown, texts: number, report: ApplyReport): MarkAnchor | null {
  if (!entry || typeof entry !== "object") {
    report.malformed += 1;
    return null;
  }

  const record = entry as Record<string, unknown>;
  const index = readIndex(record, ["t", "i", "index", "bloc", "numero", "numéro"]);
  const mark = readText(record, ["m", "mark", "marque", "type", "couleur", "color"]);
  const quote = readText(record, ["q", "quote", "passage", "extrait", "texte", "text"]);

  if (index === null || !mark || !quote) {
    report.malformed += 1;
    return null;
  }
  if (index < 0 || index >= texts) {
    report.stray += 1;
    return null;
  }

  const normalized = mark.trim().toLowerCase();
  const kind = KIND_ALIASES[normalized];
  if (kind && kind !== "highlight") return { text: index, kind, colour: null, quote };

  // Une teinte inventée laisserait « framboise| » dans la phrase : seules les cinq passent.
  if ((SHEET_HIGHLIGHTS as readonly string[]).includes(normalized)) {
    return { text: index, kind: "highlight", colour: normalized, quote };
  }
  // « surligneur » sans teinte : le jaune est le feutre par défaut du prompt d'écriture.
  if (kind === "highlight") return { text: index, kind, colour: SHEET_HIGHLIGHTS[0], quote };

  report.malformed += 1;
  return null;
}

/** Le rang du texte. Un modèle qui écrit `"t":"2"` dit la même chose que `"t":2`. */
function readIndex(record: Record<string, unknown>, keys: readonly string[]): number | null {
  for (const key of keys) {
    const value = record[key];
    if (typeof value === "number" && Number.isInteger(value)) return value;
    if (typeof value === "string" && /^\d+$/.test(value.trim())) return Number(value.trim());
  }
  return null;
}

function readText(record: Record<string, unknown>, keys: readonly string[]): string | null {
  for (const key of keys) {
    const value = record[key];
    if (typeof value === "string" && value.trim().length > 0) return value;
  }
  return null;
}

/** Un tableau caché sous une propriété unique : `{"marques": [...]}`. */
function unwrapArray(parsed: unknown): unknown[] | null {
  if (!parsed || typeof parsed !== "object") return null;
  const values = Object.values(parsed as Record<string, unknown>);
  const arrays = values.filter(Array.isArray);
  return arrays.length === 1 ? arrays[0] as unknown[] : null;
}

/**
 * **Pose les marques sur la fiche.**
 *
 * Les textes sont parcourus dans le même ordre que `textsToMark`, et c'est ce qui donne son
 * sens au `t` d'une marque. Un texte sans marque à poser n'est pas touché du tout : la passe
 * ne peut, par construction, qu'ajouter des marqueurs à des endroits qu'elle a validés.
 */
export function applyAnchors(
  blocks: readonly SheetBlock[],
  anchors: readonly MarkAnchor[],
  report: ApplyReport = emptyApplyReport(),
): SheetBlock[] {
  if (anchors.length === 0) return [...blocks];

  const byText = new Map<number, MarkAnchor[]>();
  for (const anchor of anchors) {
    const own = byText.get(anchor.text);
    if (own) own.push(anchor);
    else byText.set(anchor.text, [anchor]);
  }

  // **Deux bandes ne se touchent pas.** Un texte ne porte qu'un surligneur (`fits`), mais
  // rien n'empêchait deux points de liste consécutifs d'en porter chacun un : au rendu, les
  // deux bandes se suivent à une interligne d'écart et se lisent comme une seule, plus
  // épaisse. Un texte qui suit un texte surligné ne reçoit donc pas de bande.
  let cursor = 0;
  let previousHighlighted = false;
  const next = (original: string): string => {
    const own = byText.get(cursor);
    cursor += 1;
    if (!own) {
      previousHighlighted = original.includes("==");
      return original;
    }
    const written = applyToText(original, own, report, !previousHighlighted);
    previousHighlighted = written.includes("==");
    return written;
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

/** Une marque retenue, résolue en positions dans le texte. */
interface Placed {
  from: number;
  to: number;
  kind: MarkKind;
  colour: string;
}

function applyToText(
  text: string,
  anchors: readonly MarkAnchor[],
  report: ApplyReport,
  allowHighlight: boolean,
): string {
  const existing = markedRanges(text);
  const placed: Placed[] = [];

  for (const anchor of anchors) {
    const quote = anchor.quote.trim();
    if (quote.length === 0) {
      report.malformed += 1;
      continue;
    }

    // Une seule occurrence, sinon on ne sait pas laquelle le modèle visait - et marquer la
    // première serait marquer au hasard une fois sur deux.
    const from = text.indexOf(quote);
    if (from === -1) {
      report.absent += 1;
      continue;
    }
    if (text.indexOf(quote, from + 1) !== -1) {
      report.ambiguous += 1;
      continue;
    }

    const to = from + quote.length;
    if (anchor.kind === "highlight" && !allowHighlight) {
      report.crossing += 1;
      continue;
    }
    if (placeable(text, from, to, anchor.kind) !== "ok") {
      report.shape += 1;
      continue;
    }
    if (!fits([from, to], anchor.kind, existing, placed)) {
      report.crossing += 1;
      continue;
    }

    placed.push({ from, to, kind: anchor.kind, colour: anchor.colour ?? SHEET_HIGHLIGHTS[0] });
    report.placed += 1;
  }

  return placed.length === 0 ? text : insertMarkers(text, placed);
}

/** Disjointes, ou l'une strictement dans l'autre. Tout le reste se croise. */
function compatible(a: readonly [number, number], b: readonly [number, number]): boolean {
  if (a[1] <= b[0] || b[1] <= a[0]) return true;
  if (a[0] >= b[0] && a[1] <= b[1]) return true;
  if (b[0] >= a[0] && b[1] <= a[1]) return true;
  return false;
}

function overlaps(a: readonly [number, number], b: readonly [number, number]): boolean {
  return a[0] < b[1] && b[0] < a[1];
}

/**
 * La marque tient-elle sans en couper une autre ?
 *
 * Deux refus, et le second est moins évident. Une marque qui **croise** une autre produit des
 * marqueurs entrelacés - `==menthe|Le **rendement== atteint**` - que le rendu ne sait pas lire.
 * Et deux marques de la **même sorte** imbriquées ne valent pas mieux : les marqueurs
 * s'appairent dans l'ordre où ils apparaissent, donc l'ouverture de la seconde se lirait comme
 * la fermeture de la première.
 */
function fits(
  range: readonly [number, number],
  kind: MarkKind,
  existing: readonly MarkedRange[],
  placed: readonly Placed[],
): boolean {
  // **Un seul surligneur par texte.** Le prompt le demandait déjà, et rien ne le vérifiait :
  // sur une fiche courante, deux bandes de couleurs différentes se retrouvaient collées dans
  // le même paragraphe, une jaune puis une lilas, sans blanc entre les deux. Le code couleur
  // ne veut plus rien dire à cette densité - c'est du confetti, pas un repérage.
  if (kind === "highlight") {
    if (existing.some((mark) => mark.kind === "highlight")) return false;
    if (placed.some((mark) => mark.kind === "highlight")) return false;
  }

  for (const mark of existing) {
    if (!compatible(range, mark.outer)) return false;
    if (mark.kind === kind && overlaps(range, mark.outer)) return false;
  }

  for (const mark of placed) {
    const other: [number, number] = [mark.from, mark.to];
    if (!compatible(range, other)) return false;
    if (mark.kind === kind && overlaps(range, other)) return false;
  }

  return true;
}

/** Le rang d'emboîtement : le surligneur enveloppe, le gras et l'italique se posent dedans. */
const NESTING: Record<MarkKind, number> = { highlight: 0, bold: 1, italic: 2 };

/**
 * Insère les marqueurs, du plus enveloppant au plus intérieur.
 *
 * Deux marqueurs peuvent tomber au même endroit, et l'ordre y est tout : au même rang, les
 * fermetures passent avant les ouvertures, et la plus intérieure d'abord. C'est ce qui donne
 * `==jaune|un **terme**==` et non `==jaune|un **terme==**`.
 */
function insertMarkers(text: string, ranges: readonly Placed[]): string {
  const cuts: Array<{ at: number; marker: string; rank: number }> = [];

  for (const range of ranges) {
    cuts.push({
      at: range.from,
      marker: openerFor(range.kind, range.colour),
      rank: NESTING[range.kind],
    });
    cuts.push({
      at: range.to,
      marker: closerFor(range.kind),
      rank: -NESTING[range.kind] - 1,
    });
  }

  cuts.sort((a, b) => a.at - b.at || a.rank - b.rank);

  let out = "";
  let cursor = 0;
  for (const cut of cuts) {
    out += text.slice(cursor, cut.at) + cut.marker;
    cursor = cut.at;
  }

  return out + text.slice(cursor);
}

/**
 * Retire les marques mal posées de toute une fiche.
 *
 * Appliqué aux **deux** passes : celle qui écrit la fiche pose parfois un surligneur au milieu
 * d'un mot. La passe de marquage, elle, ne peut plus en poser de travers - `placeable` juge
 * avant d'écrire - mais la fiche qu'elle reçoit en porte, et c'est le même nettoyage qui les
 * retire. Voir `mark-shape.ts` pour ce qui est jugé.
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

export { emptyShapeReport, type MarkKind, type ShapeReport };
