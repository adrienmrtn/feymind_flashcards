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

/** Les textes d'une fiche, à plat, dans l'ordre où la pose les redistribue. */
export function textsToMark(blocks: readonly SheetBlock[]): string[] {
  return blocks.flatMap(textsOf);
}

/** Un lot de textes, et son rang de départ dans la fiche. */
export interface Lot {
  texts: string[];
  /** Rang du premier texte du lot. C'est ce qui recolle un `t` de réponse au bon bloc. */
  offset: number;
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
 * redevient donc l'**entrée**, et une fiche courante tient en un ou deux appels au lieu de
 * sept — autant de fois le prompt système de mille jetons qu'on ne paie plus.
 *
 * Vingt-quatre et non « tout », parce que l'autre raison des petits lots tenait, elle, à
 * l'attention : à quinze textes, l'ancienne passe lisait la consigne et recopiait. Cet
 * échec-là était un échec de recopie, et recopier n'est plus la tâche ; reste qu'on ne remonte
 * pas un plafond sur un raisonnement. Ces deux nombres sont à relever après mesure de
 * `placed` et de `absent` sur des fiches réelles, pas avant.
 */
export const LOT_LIMITS = { texts: 24, chars: 12_000 } as const;

export function batched(
  texts: readonly string[],
  limits: { texts: number; chars: number } = LOT_LIMITS,
): Lot[] {
  const lots: Lot[] = [];
  let current: string[] = [];
  let chars = 0;
  let offset = 0;

  for (const text of texts) {
    // Un texte seul plus gros que le plafond part quand même : le laisser de côté le perdrait,
    // et un paragraphe de douze mille caractères n'existe pas sur une fiche.
    const full = current.length >= limits.texts || chars + text.length > limits.chars;
    if (current.length > 0 && full) {
      lots.push({ texts: current, offset });
      offset += current.length;
      current = [];
      chars = 0;
    }
    current.push(text);
    chars += text.length;
  }

  if (current.length > 0) lots.push({ texts: current, offset });
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
- un surligneur : le trait de feutre sous une phrase courte ou un fragment qu'on doit pouvoir réciter. Entre douze et deux cent quarante caractères. Pas trois mots isolés, pas un texte entier, et un seul par texte.

LE CODE COULEUR
Une couleur dit une SORTE d'information, la même d'un bout à l'autre de la fiche. C'est ce qui permet de retrouver tous les chiffres d'un chapitre en diagonale.
- jaune : la définition, la thèse, la phrase que l'étudiant devra pouvoir réciter.
- menthe : un résultat chiffré, un seuil, un ordre de grandeur, avec son unité.
- bleu : un mécanisme, un enchaînement de causes, une condition d'application.
- rose : une exception, une limite, une confusion classique, ce qui se rate à l'examen.
- lilas : un repère : un nom propre, un auteur, une œuvre, une loi, un événement daté.
Le jaune reste le plus fréquent. Au moins trois couleurs différentes dès que tu poses quatre surligneurs.

OÙ NE PAS MARQUER
- Entre $ et $ : c'est une formule, tu n'y touches pas et tu ne marques rien à l'intérieur.
- Sur un passage qui porte déjà une marque : ce qui est marqué le reste.
- À cheval sur une marque existante : ton passage s'ouvre et se ferme dans la même zone non marquée.
- Un gras peut se trouver dans un passage surligné, à condition d'y être ENTIÈREMENT.

CE QUE TU DOIS AVOIR POSÉ EN FINISSANT
Le message qui accompagne les textes donne le nombre de marques attendues pour ce lot, et c'est un MINIMUM. Ces marques manquent : c'est la raison pour laquelle on te repasse la fiche. Si tu ne trouves pas d'italique, cherche mieux - le mot d'origine étrangère ou latine, le nom d'une œuvre ou d'une loi, le terme employé en tant que mot, la condition qui restreint un résultat, les deux termes voisins qu'un étudiant confond : un de ces cas est présent dans presque tout cours.

UNE LISTE VIDE EST UNE ERREUR
Tu ne relis pas pour valider, tu marques. Chaque texte de plus de cent caractères ressort avec au moins une marque. Rendre un tableau vide est le seul échec possible de cette tâche.

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
export function markPrompt(texts: readonly string[]): string {
  const target = markTargets(texts);
  const chars = texts.reduce((total, text) => total + text.length, 0);
  const numbered = texts.map((text, index) => `[${index}] ${text}`).join("\n");

  const plural = texts.length > 1 ? "s" : "";

  return `Voici ${texts.length} texte${plural} de la fiche, numéroté${plural}, ${chars} caractères en tout.

À poser sur ce lot, au minimum : ${target.bold} marques "gras", ${target.highlight} surligneurs et ${target.italic} marques "italique". Rends la liste JSON des marques, et rien d'autre.

${numbered}`;
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

  let cursor = 0;
  const next = (original: string): string => {
    const own = byText.get(cursor);
    cursor += 1;
    return own ? applyToText(original, own, report) : original;
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
