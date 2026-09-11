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
 */
const RULES: Rule[] = [
  { marker: "==", min: 12, max: 240, colour: true },
  { marker: "**", min: 1, max: 90 },
  { marker: "*", min: 1, max: 70 },
];

/** Ce qui peut précéder une ouverture : un début, une espace, une ponctuation ouvrante. */
const BEFORE_OPEN = /[\s(\[«"'’‘“\-—:;,.!?]/;
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
