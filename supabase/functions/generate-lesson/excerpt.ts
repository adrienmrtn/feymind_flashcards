/**
 * **Ce qu'un thème lit des supports : son passage, pas le document entier.**
 *
 * Le plan lit tout, et il le faut : c'est lui qui découpe. Mais chaque thème recevait ensuite
 * le document en entier, jusqu'à soixante mille caractères, pour écrire cinq blocs de notes.
 * Une leçon de huit thèmes envoyait donc le document neuf fois. Facturé à l'appel, comme chez
 * fal, ça ne coûte rien de plus ; facturé au jeton, comme sur le repli Gemini, c'est neuf
 * dixièmes de ce qui entre. Et un thème qui lit soixante pages pour en tirer une idée s'y
 * noie : son passage l'aide à rester sur son sujet.
 *
 * ## Comment le passage est choisi
 *
 * Sans appel au modèle, qui coûterait ce qu'on économise, et sans l'app : les versions
 * installées envoient le texte entier, et c'est ici qu'il est réduit, pour elles aussi.
 *
 * - Le support est coupé en passages de la taille d'un paragraphe.
 * - Chaque passage reçoit une note pour le thème : les mots du titre qu'il contient, pesés
 *   par leur rareté (un mot présent partout ne désigne rien) et par le nombre de titres qui
 *   le partagent (« guerre » dans tous les thèmes d'une leçon sur la guerre froide ne
 *   distingue aucun thème).
 * - S'y ajoute la place : les thèmes sont écrits « dans l'ordre où on les apprend », et pour
 *   un cours c'est l'ordre du document. Le thème `i` sur `N` est donc cherché autour du
 *   `i`-ième `N`-ième du texte. Quand aucun mot du titre ne se retrouve, c'est elle seule
 *   qui décide, et le thème lit sa part du document.
 * - Les meilleurs passages sont gardés jusqu'au budget, et rendus dans l'ordre du document.
 *
 * Un support court part entier : en deçà de `WHOLE_SOURCE`, couper n'économise presque rien
 * et risque de retirer la phrase qui comptait.
 *
 * Tout est pur : aucune entrée-sortie, et chaque règle a son test.
 */

/** En deçà, le support part entier. C'est à peu près la médiane des cours importés. */
export const WHOLE_SOURCE = 12_000;

/**
 * Le budget d'un thème : trois fois sa part du document, borné des deux côtés.
 *
 * Trois parts, et pas une : un thème déborde sur ses voisins, et une définition posée en
 * début de cours sert souvent trois chapitres plus loin.
 */
export const EXCERPT = { share: 3, min: 8_000, max: 16_000 } as const;

/** La taille visée d'un passage : un paragraphe, ou quelques lignes recollées. */
const PASSAGE = 800;
/** En deçà, un passage est un titre ou une ligne isolée : il s'accroche au paragraphe suivant. */
const SHORT_PASSAGE = 200;
/** Au-delà, une ligne est coupée à ses phrases : un PDF rend parfois une page en une ligne. */
const LONG_LINE = 1_600;
/** Le poids de la place face aux mots : une correspondance nette l'emporte sur la proximité. */
const POSITION_WEIGHT = 0.6;
/** La marque d'une coupure entre deux extraits, que le prompt annonce au modèle. */
export const GAP = "[…]";

const STOPWORDS = new Set(
  [
    // Français
    "les des une dans pour par sur avec sans sous entre vers aux son ses leur leurs est sont",
    "qui que quoi dont comment pourquoi quand plus moins tres tout tous toute toutes cette ces",
    "cet ceux elle elles ils nous vous mais donc car ainsi comme deux trois faire etre avoir",
    "selon chez partie chapitre introduction conclusion notion notions principe principes",
    "definition definitions exemple exemples role roles",
    // Anglais
    "the and for with from into its their what how why when are was were this that these",
    "those between about part chapter example examples",
  ].join(" ").split(" "),
);

interface Passage {
  text: string;
  /** Le milieu du passage, en fraction du document : 0 au début, 1 à la fin. */
  position: number;
  /** Faux quand rien ne le sépare du passage précédent dans le document. */
  breakBefore: boolean;
  terms: Set<string>;
}

/**
 * Les passages du document qui servent le thème `index`, ou le document entier quand il est
 * court. `themes` est la liste complète des titres, dans l'ordre du plan.
 */
export function excerptForTheme(context: string, themes: readonly string[], index: number): string {
  const text = context.trim();
  if (text.length <= WHOLE_SOURCE || themes.length === 0) return text;

  const budget = excerptBudget(text.length, themes.length);
  if (budget >= text.length) return text;

  const passages = splitPassages(text);
  if (passages.length <= 1) return text.slice(0, budget);

  const scores = scorePassages(passages, themes, index);
  const order = passages
    .map((_, rank) => rank)
    .sort((a, b) => scores[b]! - scores[a]! || a - b);

  const kept = new Set<number>();
  let used = 0;
  for (const rank of order) {
    const length = passages[rank]!.text.length;
    if (used + length > budget) continue;
    kept.add(rank);
    used += length;
  }

  let out = "";
  let previous = -2;
  for (let rank = 0; rank < passages.length; rank += 1) {
    if (!kept.has(rank)) continue;
    const passage = passages[rank]!;
    if (out.length > 0) {
      out += previous === rank - 1 ? (passage.breakBefore ? "\n\n" : "\n") : `\n\n${GAP}\n\n`;
    }
    out += passage.text;
    previous = rank;
  }
  return out;
}

/** Trois parts du document par thème, entre `EXCERPT.min` et `EXCERPT.max`. */
export function excerptBudget(length: number, themes: number): number {
  const share = Math.round((EXCERPT.share * length) / Math.max(1, themes));
  return Math.min(EXCERPT.max, Math.max(EXCERPT.min, share));
}

/**
 * Le document en passages, dans l'ordre : les lignes recollées jusqu'à `PASSAGE`, une ligne
 * trop longue coupée à ses phrases. Rien n'est perdu ni réécrit : mis bout à bout, les
 * passages redonnent le texte, aux sauts de ligne près.
 */
export function splitPassages(text: string): Passage[] {
  // Les morceaux : une ligne, ou une phrase d'une ligne trop longue, et s'il ouvre un paragraphe.
  const pieces: { text: string; opens: boolean }[] = [];
  let blank = false;
  for (const raw of text.split("\n")) {
    const value = raw.trim();
    if (!value) {
      blank = true;
      continue;
    }
    const parts = value.length > LONG_LINE ? sentences(value) : [value];
    parts.forEach((part, order) => pieces.push({ text: part, opens: order === 0 && blank }));
    blank = false;
  }

  // Un paragraphe ferme le passage, sauf quand le passage n'est qu'un titre : « Chapitre 2 :
  // la crise » vaut mieux collé au paragraphe qu'il annonce que seul.
  const groups: { text: string; opens: boolean }[] = [];
  for (const piece of pieces) {
    const last = groups[groups.length - 1];
    const fits = last !== undefined && last.text.length + piece.text.length <= PASSAGE;
    if (last && fits && (!piece.opens || last.text.length < SHORT_PASSAGE)) {
      last.text += piece.opens ? `\n\n${piece.text}` : `\n${piece.text}`;
    } else {
      groups.push({ ...piece });
    }
  }

  // La place se compte en caractères de passages : une ligne de vingt mille caractères
  // compte pour ce qu'elle pèse, pas pour une ligne.
  const total = groups.reduce((sum, group) => sum + group.text.length, 0);
  let before = 0;
  return groups.map((group) => {
    const position = (before + group.text.length / 2) / Math.max(1, total);
    before += group.text.length;
    return {
      text: group.text,
      position,
      breakBefore: group.opens,
      terms: new Set(termsOf(group.text)),
    };
  });
}

/** Une ligne trop longue, coupée à ses fins de phrase en morceaux de `PASSAGE` environ. */
function sentences(line: string): string[] {
  const out: string[] = [];
  let current = "";
  for (const sentence of line.split(/(?<=[.!?;:])\s+/)) {
    if (current && current.length + sentence.length + 1 > PASSAGE) {
      out.push(current);
      current = "";
    }
    current = current ? `${current} ${sentence}` : sentence;
    // Une « phrase » sans ponctuation sur des milliers de caractères : coupée net.
    while (current.length > LONG_LINE) {
      out.push(current.slice(0, PASSAGE));
      current = current.slice(PASSAGE);
    }
  }
  if (current) out.push(current);
  return out;
}

/** La note de chaque passage pour le thème `index`, mots et place réunis. */
function scorePassages(
  passages: readonly Passage[],
  themes: readonly string[],
  index: number,
): number[] {
  const titleTerms = themes.map((title) => new Set(termsOf(title)));
  const own = titleTerms[index] ?? new Set<string>();

  // Combien de passages, et combien de titres, portent chaque mot du thème.
  const weights = new Map<string, number>();
  for (const term of own) {
    const inPassages = passages.filter((passage) => passage.terms.has(term)).length;
    if (inPassages === 0) continue;
    const inTitles = titleTerms.filter((terms) => terms.has(term)).length;
    weights.set(term, Math.log(1 + passages.length / inPassages) / Math.max(1, inTitles));
  }
  const total = [...weights.values()].reduce((sum, weight) => sum + weight, 0);

  const center = (index + 0.5) / themes.length;
  const width = 1 / themes.length;

  return passages.map((passage) => {
    let words = 0;
    for (const [term, weight] of weights) {
      if (passage.terms.has(term)) words += weight;
    }
    const lexical = total > 0 ? words / total : 0;
    const distance = (passage.position - center) / width;
    return lexical + POSITION_WEIGHT * Math.exp(-0.5 * distance * distance);
  });
}

/**
 * Les mots qui portent du sens, ramenés à une racine grossière : en minuscules, sans
 * accents, sans les mots-outils, et coupés à cinq lettres pour que « crise » et « crises »,
 * « révolution » et « révolutionnaire » se retrouvent.
 */
export function termsOf(text: string): string[] {
  return text
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .split(/[^a-z0-9]+/)
    .filter((word) => word.length >= 3 && !STOPWORDS.has(word))
    .map((word) => (word.length > 5 ? word.slice(0, 5) : word));
}
