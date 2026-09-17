/**
 * La fiche d'un cours, côté serveur.
 *
 * Le modèle rend une structure de blocs ; ce fichier la ramène à ce que l'application sait
 * afficher, et en tire la version à plat qui servira de contexte aux cartes. Les garde-fous
 * sont ici et pas seulement dans le prompt : une consigne se respecte à peu près, un plafond
 * se respecte toujours.
 *
 * **Le vocabulaire s'est réduit à quatre blocs**, et c'est le changement de fond. Il y en
 * avait neuf : définition encadrée, encadré de ton, suite d'étapes, tableau, graphe à barres,
 * figure recadrée. Chacun se défendait pris isolément, et ensemble ils faisaient une page qui
 * ressemblait à une brochure - un cours n'est pas une infographie, et l'étudiant qui relit la
 * veille ne veut pas d'un graphe, il veut son cours mis au propre. Pire : ces objets étaient
 * décidés par le modèle et fermés au lecteur, alors que la fiche est **la sienne** et doit se
 * corriger comme un document.
 *
 * Reste donc ce qu'on écrit à la main sur une feuille : des titres, des paragraphes, des
 * listes, et les formules qu'on ne peut pas écrire en toutes lettres. La mise en valeur passe
 * par le balisage en ligne - gras, italique, surlignage de couleur - qui est modifiable, lui.
 *
 * Les anciens blocs ne sont pas jetés : ils sont **convertis**. Trente fiches existent en
 * base, et les faire disparaître pour changer de goût serait le pire service à rendre.
 */

import { stripEmDashes } from "./fal.ts";

export type SheetBlock =
  | { type: "heading"; level: number; text: string }
  | { type: "paragraph"; text: string }
  | { type: "list"; ordered: boolean; items: string[] }
  | { type: "formula"; latex: string; caption?: string };

/**
 * Les couleurs de surlignage.
 *
 * Cinq pastels, et pas une de plus. Le surlignage sert à retrouver un passage d'un coup
 * d'œil ; au-delà de cinq teintes on ne les distingue plus en diagonale, et une page qui en
 * porte huit n'a plus rien de mis en avant.
 *
 * **Le modèle les emploie, et selon un code.** Il marquait tout en jaune, à charge pour
 * l'étudiant de recolorer : personne ne recolore une fiche de soixante blocs, et une page
 * d'un seul feutre ne dit rien de plus qu'une page sans feutre. Une couleur porte donc une
 * sorte d'information - la définition, le chiffre, le mécanisme, l'exception, le repère -
 * et le code est écrit dans `generate-course/prompt.ts`, qui nomme ces cinq teintes. Un
 * test du prompt compare les deux listes : une couleur inventée laisserait « framboise| »
 * dans la phrase. L'étudiant recolore toujours ce qu'il veut par-dessus.
 */
export const SHEET_HIGHLIGHTS = ["jaune", "menthe", "bleu", "rose", "lilas"] as const;

export type SheetHighlight = (typeof SHEET_HIGHLIGHTS)[number];

export const DEFAULT_HIGHLIGHT: SheetHighlight = "jaune";

/**
 * Les tailles qu'un fragment de texte peut prendre.
 *
 * Deux, de part et d'autre de la taille du bloc, et c'est tout ce qu'il faut : un passage
 * qu'on veut voir de loin en feuilletant, un aparté qu'on garde sans qu'il encombre. Une
 * échelle plus fine transformerait la fiche en mise en page, et une fiche dont on règle la
 * typographie est une fiche qu'on ne révise plus.
 *
 * **Le modèle ne s'en sert pas.** Il écrit des titres et des paragraphes ; la taille d'un
 * fragment est une décision de relecture, prise par l'étudiant sur sa propre fiche.
 */
export const SHEET_TEXT_SIZES = ["petit", "grand"] as const;

export type SheetTextSize = (typeof SHEET_TEXT_SIZES)[number];

export const SHEET_LIMITS = {
  /**
   * Le plafond de blocs. Il passe de 60 à 90, et c'est délibéré.
   *
   * Les fiches sortaient courtes : le vocabulaire d'objets poussait le modèle à résumer pour
   * faire tenir un tableau et un graphe, et une notion résumée à une ligne ne se révise pas.
   * Sans objets, le budget revient au texte, et une fiche a le droit d'être longue - elle
   * remplace le cours, elle ne l'annonce pas.
   */
  blocks: 90,
  /** Une liste de plus de dix points n'est plus une liste, c'est un paragraphe mal découpé. */
  listItems: 10,
  /**
   * Nombre de passages mis en avant sur toute la fiche. Au delà, plus rien ne ressort.
   *
   * Il monte avec la longueur : douze marques sur une fiche de quatre-vingt-dix blocs, c'est
   * une page sans relief. Le garde-fou ne va toujours que dans un sens - il en retire, il n'en
   * ajoute pas. Il y avait un plancher en face, qui marquait trois passages quand le modèle
   * n'en avait marqué aucun ; il choisissait la première phrase de la bonne longueur, ce qui
   * n'est pas ce qui compte dans un cours. Une marque tombée sur la phrase d'à côté apprend la
   * phrase d'à côté.
   */
  highlights: 24,
  /**
   * **Ce qu'un paragraphe pèse au plus, en caractères.**
   *
   * Un paragraphe de fiche fait cent cinquante caractères ; la consigne de longueur en fait
   * écrire de six cents, parce que le modèle n'a que deux façons d'allonger — des blocs de
   * plus, ou des phrases de plus — et que la seconde ne coûte rien. Six cents caractères,
   * c'est treize lignes d'iPhone d'un seul tenant : l'étudiant ne les relit pas, il les
   * saute, et c'est exactement le « pavé » qu'on lui reproche.
   *
   * Le prompt le dit maintenant, et ce plafond le tient. Il ne réécrit rien : il coupe à une
   * **fin de phrase**, ce qui rend deux paragraphes dont chacun est de la prose valide.
   *
   * Il descend de cinq cents à trois cent vingt, la valeur que le prompt demande, plus une
   * phrase de marge. Cinq cents laissait passer des blocs de onze lignes : sur un téléphone
   * ça reste un pavé, et un pavé coupé en deux pavés n'est pas une fiche.
   */
  paragraphChars: 320,
} as const;

export function normalizeSheet(raw: unknown): SheetBlock[] {
  const source = Array.isArray(raw)
    ? raw
    : Array.isArray((raw as { blocks?: unknown })?.blocks)
    ? (raw as { blocks: unknown[] }).blocks
    : [];

  const blocks: SheetBlock[] = [];
  let highlights = 0;

  for (const entry of source) {
    if (blocks.length >= SHEET_LIMITS.blocks) break;
    if (!entry || typeof entry !== "object") continue;

    const record = entry as Record<string, unknown>;
    const type = typeof record.type === "string" ? record.type.trim().toLowerCase() : "";

    for (const block of normalizeBlock(type, record)) {
      if (blocks.length >= SHEET_LIMITS.blocks) break;

      // La mise en avant est plafonnée sur toute la fiche : passé le quota, les marques
      // suivantes sont retirées plutôt que de tout faire ressortir.
      const counted = countHighlights(block);
      if (highlights + counted > SHEET_LIMITS.highlights) {
        blocks.push(removeHighlights(block));
      } else {
        highlights += counted;
        blocks.push(block);
      }
    }
  }

  return blocks;
}

/**
 * Un bloc du modèle, ou de l'ancien format, ramené au vocabulaire courant.
 *
 * Rend une **liste** et non un bloc unique, parce qu'une conversion produit parfois deux
 * choses : un tableau devient son titre puis ses lignes, une suite d'étapes devient son titre
 * puis sa liste. Un bloc jeté rendrait la fiche muette là où le cours disait quelque chose.
 */
function normalizeBlock(type: string, record: Record<string, unknown>): SheetBlock[] {
  switch (type) {
    case "heading": {
      const text = cleanText(record.text ?? record.title);
      if (text.length < 2) return [];
      const level = toNumber(record.level) === 1 ? 1 : 2;
      return [{ type: "heading", level, text }];
    }

    case "paragraph": {
      const text = cleanText(record.text);
      // Le plancher passe de 30 à 12 caractères : une fiche modifiable à la main contient des
      // paragraphes courts, et couper la ligne que l'étudiant vient d'écrire serait pire que
      // tout ce que ce plancher protège.
      if (text.length < 12) return [];
      return splitParagraph(text).map((part) => ({ type: "paragraph", text: part }));
    }

    case "list": {
      const items = itemsOf(record.items);
      if (items.length === 0) return [];
      return [{ type: "list", ordered: record.ordered === true, items }];
    }

    case "formula": {
      const raw = typeof record.latex === "string"
        ? record.latex.trim().replace(/^\$+|\$+$/g, "").trim()
        : cleanText(record.text);
      const latex = restoreLatexCommands(raw);
      if (latex.length < 2) return [];
      return [{ type: "formula", latex, caption: cleanOptional(record.caption) }];
    }

    // MARK: - Les blocs d'avant, convertis plutôt que jetés

    case "definition": {
      const term = cleanText(record.term ?? record.title);
      const text = cleanText(record.text);
      if (term.length < 2 || text.length < 2) return [];
      // Le terme passe en gras dans la phrase : c'est exactement ce que la définition
      // encadrée disait, sans le cadre.
      return [{ type: "paragraph", text: `**${term}** : ${text}` }];
    }

    case "callout": {
      const text = cleanText(record.text);
      if (text.length < 2) return [];
      return [{ type: "paragraph", text }];
    }

    case "steps": {
      const items = itemsOf(record.items);
      if (items.length === 0) return [];
      const title = cleanOptional(record.title);
      const out: SheetBlock[] = [];
      if (title) out.push({ type: "paragraph", text: `**${title}**` });
      out.push({ type: "list", ordered: true, items });
      return out;
    }

    case "table": {
      const headers = (Array.isArray(record.headers) ? record.headers : []).map(cellText);
      const rows = (Array.isArray(record.rows) ? record.rows : [])
        .map((row) => (Array.isArray(row) ? row.map(cellText) : []))
        .filter((row) => row.some((cell) => cell.length > 0));
      if (rows.length === 0) return [];

      const out: SheetBlock[] = [];
      const title = cleanOptional(record.title);
      if (title) out.push({ type: "paragraph", text: `**${title}**` });

      // Une ligne devient « colonne : valeur, colonne : valeur ». C'est ce que la mise à plat
      // faisait déjà pour le modèle des cartes ; la fiche le lit maintenant pareil.
      const items = rows
        .map((row) =>
          row
            .map((cell, index) => [headers[index] ?? "", cell])
            .filter(([, value]) => value.length > 0)
            .map(([header, value]) => (header ? `**${header}** : ${value}` : value))
            .join(", ")
        )
        .filter((line) => line.length > 0)
        .slice(0, SHEET_LIMITS.listItems);
      if (items.length > 0) out.push({ type: "list", ordered: false, items });

      const caption = cleanOptional(record.caption);
      if (caption) out.push({ type: "paragraph", text: caption });
      return out;
    }

    case "chart": {
      const bars = (Array.isArray(record.bars) ? record.bars : [])
        .map((bar) => {
          if (!bar || typeof bar !== "object") return null;
          const entry = bar as Record<string, unknown>;
          const label = cleanText(entry.label);
          const value = toNumber(entry.value);
          if (label.length === 0 || value === null) return null;
          return { label, value };
        })
        .filter((bar): bar is { label: string; value: number } => bar !== null);
      if (bars.length === 0) return [];

      const out: SheetBlock[] = [];
      const title = cleanOptional(record.title);
      if (title) out.push({ type: "paragraph", text: `**${title}**` });
      const unit = cleanOptional(record.unit);
      out.push({
        type: "list",
        ordered: false,
        items: bars
          .slice(0, SHEET_LIMITS.listItems)
          .map((bar) => `**${bar.label}** : ${bar.value}${unit ? ` ${unit}` : ""}`),
      });
      return out;
    }

    // Les figures avaient déjà quitté les fiches : une image recadrée d'un scan était
    // décorative et souvent illisible. La légende, elle, disait quelque chose.
    case "figure": {
      const caption = cleanText(record.caption ?? record.text ?? record.title);
      if (caption.length < 4) return [];
      return [{ type: "paragraph", text: caption }];
    }

    default:
      return [];
  }
}

/** Les points d'une liste, nettoyés et bornés. */
function itemsOf(raw: unknown): string[] {
  return (Array.isArray(raw) ? raw : [])
    .map(cellText)
    .filter((item) => item.length > 0)
    .slice(0, SHEET_LIMITS.listItems);
}

function textsOf(block: SheetBlock): string[] {
  switch (block.type) {
    case "heading":
    case "paragraph":
      return [block.text];
    case "list":
      return block.items;
    case "formula":
      return [block.caption ?? ""];
  }
}

function countHighlights(block: SheetBlock): number {
  return textsOf(block).reduce((total, text) => total + Math.floor((text.match(/==/g)?.length ?? 0) / 2), 0);
}

function removeHighlights(block: SheetBlock): SheetBlock {
  const strip = (text: string) => text.replace(/==/g, "");

  switch (block.type) {
    case "heading":
    case "paragraph":
      return { ...block, text: strip(block.text) };
    case "list":
      return { ...block, items: block.items.map(strip) };
    default:
      return block;
  }
}

/** Retire le balisage en ligne : c'est la version qui part au modèle pour les cartes. */
/**
 * **Rend son antislash à une commande LaTeX déjà enregistrée.**
 *
 * Le mal est réparé à la lecture du modèle (`repairLatexEscapes`), mais les fiches écrites
 * avant lui portent la cicatrice : `\rightarrow` mal échappé est une échappée JSON valide,
 * donc `2H_2O\rightarrow4H^+` a été enregistré comme un **retour chariot** suivi de
 * « ightarrow ». Rien ne le signale, et l'équation s'affiche amputée de sa flèche.
 *
 * Un caractère de contrôle collé à une lettre n'a aucun sens dans une formule : la
 * restitution n'a donc rien à deviner. Les cinq concernés sont exactement les cinq échappées
 * JSON d'une seule lettre qui commencent aussi des commandes courantes : `\b`, `\f`,
 * `\n`, `\r`, `\t` pour `\beta`, `\frac`, `\nabla`, `\rightarrow`, `\times`.
 */
const CONTROL_TO_COMMAND: Record<string, string> = {
  "\b": "b",
  "\f": "f",
  "\n": "n",
  "\r": "r",
  "\t": "t",
};

export function restoreLatexCommands(latex: string): string {
  return latex.replace(
    /[\b\f\n\r\t](?=[A-Za-z])/g,
    (control) => "\\" + CONTROL_TO_COMMAND[control],
  );
}

/**
 * **Un paragraphe trop long, coupé à une fin de phrase.**
 *
 * C'est un filet, pas une réécriture : on ne change pas un mot, on ne résume pas, on ne
 * recompose pas. On cherche les fins de phrase et on empile les phrases jusqu'au plafond.
 * Deux paragraphes de prose valide valent mieux qu'un pavé de treize lignes, et l'étudiant
 * peut de toute façon les recoller à la main — l'inverse lui demandait de retrouver où la
 * phrase s'arrête.
 *
 * **On ne coupe jamais au milieu d'une phrase.** Quand une seule phrase dépasse le plafond,
 * elle sort telle quelle : une phrase tranchée en deux blocs se lit comme un bug d'affichage,
 * et le remède serait pire que le mal.
 *
 * Jumeau de `SheetText.split` côté iPhone. Les deux doivent découper la même fiche de la
 * même façon, sinon elle se lit différemment selon l'appareil.
 */
export function splitParagraph(
  text: string,
  limit: number = SHEET_LIMITS.paragraphChars,
): string[] {
  if (text.length <= limit) return [text];

  const pieces = sentences(text);
  if (pieces.length < 2) return [text];

  const parts: string[] = [];
  let current = "";
  for (const piece of pieces) {
    const merged = current ? `${current} ${piece}` : piece;
    if (current && merged.length > limit) {
      parts.push(current);
      current = piece;
    } else {
      current = merged;
    }
  }
  if (current) parts.push(current);

  // Une queue d'une demi-ligne se lit comme une coupure ratée, pas comme un paragraphe.
  // Elle repart avec celui qui la précède, quitte à lui faire dépasser le plafond.
  if (parts.length > 1 && parts[parts.length - 1]!.length < 60) {
    const tail = parts.pop()!;
    parts[parts.length - 1] = `${parts[parts.length - 1]} ${tail}`;
  }

  return parts.length > 0 ? parts : [text];
}

/** Les fins de phrase d'un texte, hors formules et hors marques. */
function sentences(text: string): string[] {
  const closed = protectedSpans(text);
  const inside = (index: number) =>
    closed.some(([from, to]) => index >= from && index < to);

  const out: string[] = [];
  let start = 0;

  for (let index = 0; index < text.length; index += 1) {
    if (!".!?…".includes(text[index]!)) continue;
    if (inside(index)) continue;

    // Une initiale n'est pas une fin de phrase : « M. Dupont », « J. Monod ».
    const before = index >= 2 ? text[index - 1]! : "";
    const beforeThat = index >= 2 ? text[index - 2]! : " ";
    if (before.length === 1 && before === before.toLocaleUpperCase() && before !== before.toLocaleLowerCase() && /\s/.test(beforeThat)) {
      continue;
    }

    const after = /^(\s+)(\S)/.exec(text.slice(index + 1));
    if (!after) continue;
    // Ce qui ouvre la phrase suivante : une capitale, un chiffre, un guillemet, ou le
    // marqueur d'un terme en gras — « **La réplication** … » commence par une étoile.
    if (!/[\p{Lu}\p{Nd}*=$«"(\[]/u.test(after[2]!)) continue;

    const sentence = text.slice(start, index + 1).trim();
    // Trop court pour être une phrase : c'est une abréviation qu'on a prise pour un point.
    if (sentence.length < 40) continue;

    out.push(sentence);
    start = index + 1 + after[1]!.length;
  }

  const rest = text.slice(start).trim();
  if (rest) out.push(rest);
  return out;
}

/**
 * Les portions qu'une coupure ne doit pas traverser : les formules et les marques.
 *
 * Un point dans `$3.14$` n'est pas une fin de phrase, et une coupure au milieu d'un
 * `**terme**` laisserait deux étoiles orphelines dans chaque moitié.
 */
function protectedSpans(text: string): [number, number][] {
  const spans: [number, number][] = [];
  for (const marker of ["$", "**", "=="]) {
    let index = 0;
    while (index < text.length) {
      const open = text.indexOf(marker, index);
      if (open < 0) break;
      const close = text.indexOf(marker, open + marker.length);
      if (close < 0) break;
      spans.push([open, close + marker.length]);
      index = close + marker.length;
    }
  }
  return spans;
}

export function stripInlineMarkup(text: string): string {
  return text
    // La couleur d'un surligneur s'écrit à l'ouverture de la marque - `==menthe|texte==` -
    // et n'appartient qu'au rendu. Sans cette ligne, le modèle recevrait « menthe|texte »
    // et le nom de la couleur se réviserait avec le cours.
    .replace(new RegExp(`==(?:${SHEET_HIGHLIGHTS.join("|")})\\|`, "gi"), "")
    // Même chose pour la taille d'un fragment : `^^grand|texte^^` n'est pas du contenu.
    .replace(new RegExp(`\\^\\^(?:${SHEET_TEXT_SIZES.join("|")})\\|`, "gi"), "")
    .replace(/\*\*/g, "")
    .replace(/==/g, "")
    .replace(/\^\^/g, "")
    .replace(/~~/g, "")
    .replace(/\*/g, "")
    .replace(/`/g, "")
    .replace(/\$/g, "")
    .replace(/\s{2,}/g, " ")
    .trim();
}

/**
 * **Le chapeau d'une fiche : vingt mots, jamais plus.**
 *
 * Il se lit entre le titre et la première partie, dans un corps plus grand que le texte. À
 * cette taille, deux phrases pleines occupent le haut de l'écran et repoussent la fiche sous
 * la ligne de flottaison : on ouvre un cours et on lit d'abord un résumé du cours. Or ce n'est
 * pas ce qu'on vient chercher - le résumé sert à reconnaître la fiche, pas à la remplacer.
 *
 * Vingt mots tiennent sur deux lignes de téléphone. C'est assez pour dire l'enjeu, et trop peu
 * pour raconter le cours : la contrainte fait le travail que la consigne seule ne fait pas.
 *
 * **La coupe respecte les phrases.** On garde les phrases entières tant qu'elles tiennent dans
 * le compte ; une phrase coupée en son milieu se lit comme une panne, et le modèle en écrit
 * régulièrement une seule, plus longue que la limite. Dans ce cas seulement, on coupe au
 * vingtième mot et on pose des points de suspension : mieux vaut une phrase visiblement
 * écourtée qu'une phrase qui s'arrête sans raison.
 */
export const SUMMARY_MAX_WORDS = 20;

export function clampSummary(text: string, limit = SUMMARY_MAX_WORDS): string {
  const clean = text.trim().replace(/\s+/g, " ");
  if (clean.length === 0) return "";

  const words = clean.split(" ");
  if (words.length <= limit) return clean;

  // Les phrases, bornes comprises : c'est le point qui décide où l'on peut s'arrêter.
  const sentences = clean.match(/[^.!?…]+[.!?…]+|[^.!?…]+$/g) ?? [clean];

  let kept = "";
  let count = 0;
  for (const sentence of sentences) {
    const size = sentence.trim().split(" ").filter(Boolean).length;
    if (count + size > limit) break;
    kept += sentence;
    count += size;
  }

  const trimmed = kept.trim();
  if (trimmed.length > 0) return trimmed;

  // Pas une seule phrase ne tient : on coupe au mot, sans laisser de ponctuation pendante.
  return words.slice(0, limit).join(" ").replace(/[\s,;:.!?…]+$/, "") + "…";
}

/**
 * La fiche à plat, une notion par ligne.
 *
 * C'est le contexte envoyé au modèle quand il faut écrire des cartes ou expliquer un
 * passage. Les valeurs des tableaux et des graphes y sont **conservées**, avec le nom de
 * leur colonne : « Phase photochimique : thylakoïdes » se révise, « thylakoïdes » seul non.
 */
export function sheetToPlainText(blocks: SheetBlock[]): string {
  const lines: string[] = [];

  for (const block of blocks) {
    switch (block.type) {
      case "heading":
      case "paragraph":
        lines.push(stripInlineMarkup(block.text));
        break;

      case "list":
        block.items.forEach((item, index) =>
          lines.push(block.ordered ? `${index + 1}. ${stripInlineMarkup(item)}` : stripInlineMarkup(item))
        );
        break;

      case "formula":
        lines.push(
          block.caption ? `${block.latex} (${stripInlineMarkup(block.caption)})` : block.latex,
        );
        break;
    }
  }

  return lines.filter((line) => line.length > 0).join("\n");
}

function cleanText(value: unknown): string {
  if (typeof value !== "string") return "";

  let text = stripEmDashes(value)
    .replace(/\u00A0/g, " ")
    .replace(/\r?\n+/g, " ");

  // Une puce ou un dièse en tête de bloc est du markdown qui a fui hors de sa structure :
  // le bloc porte déjà sa forme.
  text = text.replace(/^\s*(?:[-•◦·>]|#{1,6}|\d+[.)])\s+/, "");

  return text.replace(/\s{2,}/g, " ").trim();
}

function cleanOptional(value: unknown): string | undefined {
  const text = cleanText(value);
  return text.length > 0 ? text : undefined;
}

function toNumber(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number.parseFloat(value.replace(/\s/g, "").replace(",", ".").replace("%", ""));
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function cellText(value: unknown): string {
  if (typeof value === "number") return String(value);
  if (typeof value === "boolean") return value ? "oui" : "non";
  return cleanText(value);
}
