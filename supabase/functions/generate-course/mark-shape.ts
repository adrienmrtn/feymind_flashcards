/**
 * **La forme d'une marque, vérifiée caractère par caractère.**
 *
 * Une marque mal posée est pire qu'une marque absente. Relevé sur une fiche de mémo
 * d'investissement, écrite par la fonction elle-même :
 *
 *     « ... fondée en 2017, issue de==rose| 35 ans de recherche du CNRS ... cherche à lever== »
 *
 * L'ouverture est collée au mot qui la précède, et la fermeture tombe deux cents caractères
 * plus loin : au rendu, c'est une bande rose sur trois phrases et un mot coupé, pas un trait
 * de feutre. Le contrôle d'avant ne pouvait pas le voir : il comparait les textes **marques
 * retirées**, et celui-ci était identique à l'original une fois les `==` ôtés.
 *
 * Ce module ne juge donc pas le contenu, il juge la **pose** : une marque s'ouvre au bord d'un
 * mot, se ferme au bord d'un mot, et couvre une longueur plausible pour ce qu'elle est - un
 * terme pour le gras, une nuance pour l'italique, une phrase courte pour le surligneur.
 *
 * Ce qui ne passe pas est **retiré**, pas rejeté : on enlève les deux marqueurs et on garde le
 * texte. Rejeter le texte entier perdrait aussi les marques bien posées du même paragraphe.
 */

/** Les cinq teintes, recopiées ici pour ne pas dépendre de l'ordre d'import. */
const COLOUR = /^(?:jaune|menthe|bleu|rose|lilas)\|/i;

interface Rule {
  /** Le marqueur, tel qu'il s'écrit. */
  marker: string;
  /** Longueur minimale du passage marqué, une fois la couleur ôtée. */
  min: number;
  /** Longueur maximale. Au delà, ce n'est plus une marque, c'est un surlignage de page. */
  max: number;
  /** Le passage peut-il porter un nom de couleur suivi d'une barre ? */
  colour?: boolean;
}

/**
 * Les bornes, et d'où elles viennent.
 *
 * Le gras tient un terme ou un groupe nominal : au delà de quatre-vingt-dix caractères, c'est
 * une phrase, et une phrase en gras ne met rien en valeur. L'italique est une nuance, plus
 * court encore. Le surligneur couvre une phrase courte ou un fragment : le plancher écarte les
 * trois mots isolés, le plafond écarte le paragraphe entier.
 *
 * **Le plafond du surligneur passe de deux cent quarante à cent quarante caractères.** Le
 * prompt disait « une phrase courte » et autorisait dans la même ligne deux cent quarante
 * caractères, ce qui fait cinq à six lignes d'iPhone : au rendu, ce n'est plus un trait de
 * feutre mais un aplat qui avale le paragraphe. Cent quarante caractères, c'est trois lignes,
 * et trois lignes se relisent d'un coup d'œil - ce qu'un surlignage est censé permettre.
 */
const RULES: Rule[] = [
  { marker: "==", min: 12, max: 140, colour: true },
  { marker: "**", min: 1, max: 90 },
  { marker: "*", min: 1, max: 70 },
];

/** Les trois sortes de marques, nommées. La repasse les désigne, elle ne les écrit plus. */
export type MarkKind = "highlight" | "bold" | "italic";

/**
 * La sorte, et la règle qui la juge.
 *
 * L'ordre compte et c'est celui de `RULES` : le gras se lit avant l'italique, sans quoi
 * chaque `**` compterait pour deux astérisques et tout le gras serait démonté.
 */
const KIND_RULE: Record<MarkKind, Rule> = {
  highlight: RULES[0]!,
  bold: RULES[1]!,
  italic: RULES[2]!,
};

/** Le marqueur d'ouverture d'une sorte, couleur comprise pour le surligneur. */
export function openerFor(kind: MarkKind, colour: string): string {
  return kind === "highlight" ? `==${colour}|` : KIND_RULE[kind].marker;
}

/** Le marqueur de fermeture : le même pour les trois, sans la couleur. */
export function closerFor(kind: MarkKind): string {
  return KIND_RULE[kind].marker;
}

/** Ce qui peut précéder une ouverture : un début, une espace, une ponctuation ouvrante. */
const BEFORE_OPEN = /[\s(\[«"'’‘“\-—:;,.!?]/;
/**
 * Ce qui ferme la proposition d'avant, et autorise donc un surligneur à s'ouvrir.
 *
 * **La virgule n'en est pas.** C'est tout l'objet de la règle : une bande qui s'ouvre sur
 * « Cependant, ==une tendance différente a émergé… » ne se lit pas comme un passage retenu
 * mais comme une sélection ratée, parce qu'elle commence au milieu de la phrase qu'elle
 * prétend mettre en avant. Un trait de feutre se pose sur une proposition entière.
 */
const CLAUSE_END = /[.:;!?…]/;
/** Ce qu'on saute en remontant vers la fin de la proposition précédente. */
const BEFORE_CLAUSE = /[\s"'«»“”‘’(\[]/;
/** Ce qui peut suivre une fermeture : une fin, une espace, une ponctuation fermante. */
const AFTER_CLOSE = /[\s).,;:!?\]»"'’’”…\-]/;

/**
 * Retire les marques mal posées d'un texte, et laisse les autres intactes.
 *
 * Les fragments entre `$` et `$` sont **sautés** : un exposant s'y écrit `a^*`, une
 * multiplication `2*3`, et y chercher de l'italique casserait la formule.
 */
export interface ShapeReport {
  /** Marqueurs retirés, par raison. */
  reasons: Record<string, number>;
  /** Un exemple de passage refusé, pour comprendre sans deviner. */
  sample?: string;
}

export function emptyShapeReport(): ShapeReport {
  return { reasons: {} };
}

export function cleanMarks(text: string, report: ShapeReport = emptyShapeReport()): string {
  if (text.length === 0) return text;

  const math = mathRanges(text);
  const doomed = new Set<number>();

  for (const rule of RULES) {
    for (const position of badMarkerPositions(text, rule, math, doomed, report)) {
      doomed.add(position);
    }
  }

  if (doomed.size === 0) return text;
  return removeMarkers(text, doomed);
}

function note(report: ShapeReport, reason: string, text: string, open: number, close: number) {
  report.reasons[reason] = (report.reasons[reason] ?? 0) + 1;
  if (!report.sample) report.sample = `${reason}: ${text.slice(Math.max(0, open - 20), close + 24)}`;
}

/** Les bornes des fragments mathématiques, pour ne pas y entrer. */
function mathRanges(text: string): Array<[number, number]> {
  const ranges: Array<[number, number]> = [];
  let open = -1;
  for (let index = 0; index < text.length; index += 1) {
    if (text[index] !== "$") continue;
    if (open === -1) open = index;
    else {
      ranges.push([open, index]);
      open = -1;
    }
  }
  return ranges;
}

function insideMath(index: number, math: Array<[number, number]>): boolean {
  return math.some(([from, to]) => index >= from && index <= to);
}

/**
 * Les marqueurs à retirer pour une règle donnée.
 *
 * Les occurrences sont appariées dans l'ordre : la première ouvre, la deuxième ferme. Une
 * occurrence esseulée en fin de texte est retirée, sinon elle s'afficherait telle quelle.
 */
function* badMarkerPositions(
  text: string,
  rule: Rule,
  math: Array<[number, number]>,
  alreadyDoomed: Set<number>,
  report: ShapeReport,
): Generator<number> {
  const positions = markerPositions(text, rule, math, alreadyDoomed);

  for (let index = 0; index + 1 < positions.length; index += 2) {
    const open = positions[index]!;
    const close = positions[index + 1]!;
    const verdict = placement(text, open, close, rule);
    if (verdict === "ok") continue;
    note(report, `${rule.marker}:${verdict}`, text, open, close);
    yield open;
    yield close;
  }

  // Un marqueur sans partenaire : il ne veut rien dire et se lirait dans la phrase.
  if (positions.length % 2 === 1) {
    const orphan = positions[positions.length - 1]!;
    note(report, `${rule.marker}:orphelin`, text, orphan, orphan);
    yield orphan;
  }
}

/** Où le marqueur apparaît, hors des formules et hors des marqueurs déjà condamnés. */
function markerPositions(
  text: string,
  rule: Rule,
  math: Array<[number, number]>,
  alreadyDoomed: Set<number>,
): number[] {
  const found: number[] = [];
  let index = 0;

  while (index < text.length) {
    if (!text.startsWith(rule.marker, index)) {
      index += 1;
      continue;
    }
    // L'italique se cherche **après** le gras : sans ce saut, chaque `**` compterait pour
    // deux astérisques d'italique et tout le gras serait démonté.
    if (rule.marker === "*" && text.startsWith("**", index)) {
      index += 2;
      continue;
    }
    if (insideMath(index, math) || alreadyDoomed.has(index)) {
      index += rule.marker.length;
      continue;
    }
    found.push(index);
    index += rule.marker.length;
  }

  return found;
}

/** La marque est-elle posée au bord d'un mot, sur une longueur plausible ? Sinon, pourquoi. */
function placement(text: string, open: number, close: number, rule: Rule): string {
  const marker = rule.marker;

  const before = open === 0 ? " " : text[open - 1]!;
  if (!BEFORE_OPEN.test(before)) return "collée";

  const afterIndex = close + marker.length;
  const after = afterIndex >= text.length ? " " : text[afterIndex]!;
  if (!AFTER_CLOSE.test(after)) return "fermeture-collée";

  let inner = text.slice(open + marker.length, close);
  if (rule.colour) inner = inner.replace(COLOUR, "");
  // Une couleur écrite puis un espace : `==rose| 35 ans` s'ouvre sur une espace, ce qui
  // trahit une marque posée à l'aveugle plutôt qu'au début d'un passage.
  if (rule.colour && /^\s/.test(inner)) return "espace-après-couleur";

  const length = inner.trim().length;
  if (length < rule.min) return "trop-court";
  if (length > rule.max) return "trop-long";
  // Une marque ne saute pas une ligne, et le gras ne couvre pas deux phrases.
  if (inner.includes("\n")) return "multiligne";
  if (marker !== "==" && /[.!?]\s/.test(inner)) return "deux-phrases";

  return "ok";
}

/**
 * **Une marque peut-elle se poser sur `[from, to)` ?** Sinon, pourquoi.
 *
 * Mêmes bornes et mêmes bords de mot que `cleanMarks`, mais jugés **avant** la pose. La
 * repasse ancienne posait d'abord et laissait le nettoyage retirer : chaque marque mal placée
 * était alors payée en jetons de sortie pour finir à la poubelle. Maintenant que le modèle
 * désigne un passage au lieu de réécrire le texte, le serveur peut refuser sans rien perdre.
 */
export function placeable(text: string, from: number, to: number, kind: MarkKind): string {
  const rule = KIND_RULE[kind];
  if (from < 0 || to > text.length || to <= from) return "hors-texte";

  const before = from === 0 ? " " : text[from - 1]!;
  if (!BEFORE_OPEN.test(before)) return "collée";

  const after = to >= text.length ? " " : text[to]!;
  if (!AFTER_CLOSE.test(after)) return "fermeture-collée";

  const inner = text.slice(from, to);
  const length = inner.trim().length;
  if (length < rule.min) return "trop-court";
  if (length > rule.max) return "trop-long";
  if (inner.includes("\n")) return "multiligne";
  if (kind !== "highlight" && /[.!?]\s/.test(inner)) return "deux-phrases";
  if (kind === "highlight" && !opensClause(text, from)) return "milieu-de-phrase";

  // Un exposant s'écrit `a^*`, une multiplication `2*3` : poser une marque à cheval sur une
  // formule la casserait, et le rendu LaTeX échouerait sur toute la fiche.
  if (mathRanges(text).some(([open, close]) => from <= close && to > open)) return "formule";

  return "ok";
}

/**
 * Le passage ouvre-t-il une proposition ?
 *
 * On remonte les espaces et les guillemets ouvrants, et on regarde ce qui reste : le début du
 * texte, ou une ponctuation qui ferme ce qui précède. Une virgule, un tiret, un mot : non.
 */
export function opensClause(text: string, from: number): boolean {
  let index = from - 1;
  while (index >= 0 && BEFORE_CLAUSE.test(text[index]!)) index -= 1;
  if (index < 0) return true;
  return CLAUSE_END.test(text[index]!);
}

/** Une marque déjà posée : ce qu'elle occupe, marqueurs compris. */
export interface MarkedRange {
  kind: MarkKind;
  /** Bornes marqueurs compris, `[début, fin)`. */
  outer: [number, number];
}

/**
 * **Où sont les marques que le texte porte déjà.**
 *
 * La repasse ne travaille pas sur une page blanche : la fiche arrive marquée, mal ou peu, et
 * une marque nouvelle qui couperait une ancienne en deux produirait des marqueurs croisés -
 * `==menthe|Le **rendement== atteint**` - que le rendu ne sait pas lire. On relève donc les
 * anciennes avant de poser les nouvelles.
 */
export function markedRanges(text: string): MarkedRange[] {
  const math = mathRanges(text);
  const ranges: MarkedRange[] = [];
  const taken = new Set<number>();

  for (const kind of ["highlight", "bold", "italic"] as const) {
    const rule = KIND_RULE[kind];
    const positions = markerPositions(text, rule, math, taken);

    for (let index = 0; index + 1 < positions.length; index += 2) {
      const open = positions[index]!;
      const close = positions[index + 1]!;
      taken.add(open);
      taken.add(close);

      ranges.push({ kind, outer: [open, close + rule.marker.length] });
    }
  }

  return ranges;
}

/** Reconstruit le texte sans les marqueurs condamnés, et sans leur nom de couleur. */
function removeMarkers(text: string, doomed: Set<number>): string {
  let out = "";
  let index = 0;

  while (index < text.length) {
    if (!doomed.has(index)) {
      out += text[index];
      index += 1;
      continue;
    }

    // La longueur du marqueur se relit sur le texte : `==` et `**` font deux, `*` fait un.
    const marker = text.startsWith("==", index) || text.startsWith("**", index) ? 2 : 1;
    index += marker;

    // `==rose|` : le nom de la couleur appartient à la marque, pas à la phrase.
    if (marker === 2 && text.startsWith("==", index - 2)) {
      const rest = text.slice(index);
      const colour = rest.match(COLOUR);
      if (colour) index += colour[0].length;
    }
  }

  return out;
}
