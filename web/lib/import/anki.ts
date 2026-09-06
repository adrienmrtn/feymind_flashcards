/**
 * Reprendre un paquet Anki.
 *
 * ## Ce qu'on récupère, et ce qu'on laisse
 *
 * Un `.apkg` est un ZIP qui contient la collection - une base SQLite - et les médias. On en
 * tire **les notes**, leur paquet d'origine et leurs étiquettes, et rien de plus. Sont
 * laissés derrière :
 *
 * - **L'ordonnancement.** Les intervalles d'Anki sont ceux de SM-2 tel qu'Anki l'a réglé,
 *   avec ses propres options de paquet. Les reprendre donnerait des échéances que la file
 *   d'ici ne sait pas expliquer, et une carte due dans huit mois le jour de l'import. Tout
 *   repart neuf : c'est le seul état honnête.
 * - **Les médias.** Une image d'Anki vit dans le ZIP sous un nom numéroté ; la porter
 *   demanderait un dépôt de fichiers et une réécriture de chaque champ. Les notes qui ne
 *   sont qu'une image sont donc comptées comme laissées de côté, et annoncées.
 * - **Les modèles de note.** Un modèle Anki est deux gabarits HTML et du CSS. Ici une carte
 *   est un recto, un verso, un indice : on prend les champs, pas la mise en page.
 *
 * ## Les deux formats de collection
 *
 * Anki écrit `collection.anki2` (schéma 11, la collection en clair) quand on coche « prise
 * en charge des anciennes versions », et `collection.anki21b` sinon - la même base, mais
 * compressée en zstd, et avec un schéma où les paquets ont leur table au lieu d'un JSON.
 * Les deux sont lus : le second est la sortie par défaut d'Anki moderne, donc celui que la
 * plupart des gens auront sous la main.
 *
 * Tout se passe **dans l'onglet**. Le serveur reçoit des cartes, jamais le fichier.
 */

import { asNumber, asText, looksLikeSqlite, openSqlite, type SqliteValue } from "./sqlite";
import { looksLikeZip, readZipEntry, zipEntries } from "./zip";

export type AnkiErrorCode =
  | "notPackage"
  | "noCollection"
  | "unreadableCollection"
  | "noZstd"
  | "empty";

export class AnkiError extends Error {
  constructor(readonly code: AnkiErrorCode) {
    super(code);
  }
}

export interface AnkiCard {
  kind: "basic" | "cloze";
  front: string;
  back: string;
  hint?: string;
  /** Le paquet Anki d'origine, pour laisser choisir ce qu'on reprend. */
  deck: string;
  tags: string[];
}

export interface AnkiDeckSummary {
  name: string;
  cards: number;
}

export interface AnkiPackage {
  /** Titre proposé : le paquet Anki quand il n'y en a qu'un, sinon le nom du fichier. */
  title: string;
  decks: AnkiDeckSummary[];
  cards: AnkiCard[];
  /** Notes écartées : champ vide, image seule, modèle à un seul champ. */
  skipped: number;
}

/** Graphie unique du trou, la même que dans `generate-flashcards` et dans l'app. */
const GAP = "…";

/** Au-delà, ce n'est plus un paquet qu'on révise : c'est un dictionnaire. */
export const ANKI_CARD_LIMIT = 4_000;

const MAX_SIDE = 2_000;

export function isAnkiFileName(name: string): boolean {
  return /\.(apkg|colpkg|anki2|anki21|anki21b)$/i.test(name.trim());
}

export async function readAnkiPackage(
  bytes: Uint8Array,
  fileName = "",
): Promise<AnkiPackage> {
  const collection = looksLikeSqlite(bytes) ? bytes : await extractCollection(bytes);
  const suggested = fileName.replace(/\.[^.]+$/, "").trim();

  let database;
  try {
    database = openSqlite(collection);
  } catch {
    throw new AnkiError("unreadableCollection");
  }

  const notes = database.readRecords("notes");
  if (!notes) throw new AnkiError("unreadableCollection");

  const deckOf = deckIndex(database);
  const cards: AnkiCard[] = [];
  const counts = new Map<string, number>();
  let skipped = 0;

  for (const note of notes) {
    const fields = asText(note.flds)
      .split("\u001f")
      .map((field) => cleanField(field));
    const tags = asText(note.tags).split(/\s+/).filter(Boolean);
    const deck = deckOf(asNumber(note.id)) ?? suggested;
    const written = notesToCards(fields, deck, tags);

    if (written.length === 0) {
      skipped += 1;
      continue;
    }

    for (const card of written) {
      cards.push(card);
      counts.set(card.deck, (counts.get(card.deck) ?? 0) + 1);
      if (cards.length >= ANKI_CARD_LIMIT) break;
    }
    if (cards.length >= ANKI_CARD_LIMIT) break;
  }

  if (cards.length === 0) throw new AnkiError("empty");

  const decks = [...counts.entries()]
    .map(([name, count]) => ({ name, cards: count }))
    .sort((left, right) => right.cards - left.cards || left.name.localeCompare(right.name));

  return {
    title: decks.length === 1 ? decks[0]!.name || suggested : suggested,
    decks,
    cards,
    skipped,
  };
}

/**
 * La collection, sortie de l'archive et décompressée si besoin.
 *
 * L'ordre d'essai n'est pas arbitraire : quand une archive porte les deux, `collection.anki2`
 * est une **rétrogradation** écrite pour les vieilles versions et le `.anki21` à côté est la
 * vraie collection. Prendre le premier nom trouvé donnerait un paquet amputé de tout ce
 * qu'Anki a ajouté depuis.
 */
async function extractCollection(bytes: Uint8Array): Promise<Uint8Array> {
  if (!looksLikeZip(bytes)) throw new AnkiError("notPackage");

  const entries = zipEntries(bytes);
  const wanted = ["collection.anki21b", "collection.anki21", "collection.anki2"];
  const found = wanted
    .map((name) => entries.find((entry) => entry.name.toLowerCase().endsWith(name)))
    .find((entry) => entry !== undefined);

  if (!found) throw new AnkiError("noCollection");

  const raw = await readZipEntry(bytes, found);
  if (!raw) throw new AnkiError("unreadableCollection");
  if (looksLikeSqlite(raw)) return raw;
  return decompressZstd(raw);
}

/** Magie zstd, en tête de flux. */
function isZstd(data: Uint8Array): boolean {
  return data[0] === 0x28 && data[1] === 0xb5 && data[2] === 0x2f && data[3] === 0xfd;
}

/**
 * Le zstd n'arrive que sur le format moderne, donc le décodeur n'est chargé que là :
 * personne qui dépose un `.docx` ne doit payer ces vingt kilooctets.
 */
async function decompressZstd(data: Uint8Array): Promise<Uint8Array> {
  if (!isZstd(data)) throw new AnkiError("unreadableCollection");

  try {
    const { decompress } = await import("fzstd");
    const out = decompress(data);
    if (!looksLikeSqlite(out)) throw new AnkiError("unreadableCollection");
    return out;
  } catch (error) {
    if (error instanceof AnkiError) throw error;
    throw new AnkiError("noZstd");
  }
}

/**
 * De quel paquet vient une note.
 *
 * La réponse est dans `cards`, pas dans `notes` : c'est la carte qui appartient à un paquet.
 * Une note filtrée porte son paquet d'origine dans `odid`, et c'est celui-là qu'on veut -
 * sinon tout un import atterrit dans « Filtré », qui n'existe que le temps d'une session.
 *
 * Le nom, lui, change de place selon le schéma : une table `decks` dans le format récent, un
 * JSON dans la colonne `col.decks` dans l'ancien.
 */
function deckIndex(database: {
  readRecords(table: string): Record<string, SqliteValue>[] | null;
}): (noteId: number) => string | null {
  const names = new Map<number, string>();
  const fromTable = database.readRecords("decks");

  if (fromTable) {
    for (const row of fromTable) {
      names.set(asNumber(row.id), deckName(asText(row.name)));
    }
  } else {
    const col = database.readRecords("col")?.[0];
    try {
      const parsed = JSON.parse(asText(col?.decks) || "{}") as Record<string, { name?: unknown }>;
      for (const [id, deck] of Object.entries(parsed)) {
        if (typeof deck?.name === "string") names.set(Number(id), deckName(deck.name));
      }
    } catch {
      // Un JSON illisible : les cartes garderont le nom du fichier. Ça ne vaut pas un refus.
    }
  }

  const perNote = new Map<number, string>();
  for (const card of database.readRecords("cards") ?? []) {
    const noteId = asNumber(card.nid);
    if (perNote.has(noteId)) continue;
    const original = asNumber(card.odid);
    const name = names.get(original > 0 ? original : asNumber(card.did));
    if (name) perNote.set(noteId, name);
  }

  return (noteId) => perNote.get(noteId) ?? null;
}

/** Anki emboîte ses paquets avec un séparateur invisible ; on rend la forme qu'il affiche. */
function deckName(raw: string): string {
  return raw.replace(/\u001f/g, "::").trim();
}

/**
 * Les cartes d'une note.
 *
 * Un texte à trous donne **une carte par numéro de trou**, comme Anki : c'est ce qui fait
 * qu'un paquet de vocabulaire reste un paquet de vocabulaire après l'import. Le reste donne
 * une carte recto verso, le premier champ au recto et les suivants au verso - un modèle à
 * six champs n'est pas six cartes, c'est une carte dont la réponse est longue.
 */
export function notesToCards(fields: string[], deck: string, tags: string[]): AnkiCard[] {
  const filled = fields.map((field) => field.trim());
  const clozeAt = filled.findIndex((field) => clozeOrdinals(field).length > 0);

  if (clozeAt >= 0) {
    const text = filled[clozeAt]!;
    // Le champ « Extra » d'Anki se lit au verso de ses cartes à trous. Ici le verso est le
    // terme manquant et rien d'autre, donc il devient l'indice.
    const extra = filled.find((field, index) => index !== clozeAt && field.length > 0);
    return clozeOrdinals(text).flatMap((ordinal) => {
      const card = clozeCard(text, ordinal);
      if (!card) return [];
      const hint = card.hint ?? extra;
      return [
        {
          kind: "cloze" as const,
          front: cut(card.front),
          back: cut(card.back),
          hint: hint ? cut(hint) : undefined,
          deck,
          tags,
        },
      ];
    });
  }

  const front = filled[0] ?? "";
  const back = filled.slice(1).filter(Boolean).join("\n\n");
  if (front.length === 0 || back.length === 0) return [];

  return [{ kind: "basic", front: cut(front), back: cut(back), deck, tags }];
}

const CLOZE = /\{\{c(\d+)::([\s\S]*?)\}\}/g;

export function clozeOrdinals(text: string): number[] {
  const found = new Set<number>();
  for (const match of text.matchAll(CLOZE)) found.add(Number(match[1]));
  return [...found].sort((left, right) => left - right);
}

/**
 * Un trou, les autres découverts.
 *
 * C'est le comportement d'Anki, et il compte : sur une phrase à quatre trous, masquer les
 * quatre d'un coup ne demande plus de se souvenir, ça demande de deviner.
 */
export function clozeCard(
  text: string,
  ordinal: number,
): { front: string; back: string; hint?: string } | null {
  const answers: string[] = [];
  let hint: string | undefined;

  const front = text.replace(CLOZE, (_match, index: string, body: string) => {
    const [answer, written] = splitCloze(body);
    if (Number(index) !== ordinal) return answer;
    answers.push(answer);
    if (written && !hint) hint = written;
    return GAP;
  });

  if (answers.length === 0) return null;
  const back = [...new Set(answers.filter(Boolean))].join(" / ");
  if (back.length === 0) return null;

  return { front: front.trim(), back, hint };
}

function splitCloze(body: string): [answer: string, hint: string | undefined] {
  const separator = body.indexOf("::");
  if (separator < 0) return [body.trim(), undefined];
  return [body.slice(0, separator).trim(), body.slice(separator + 2).trim() || undefined];
}

/**
 * Un champ Anki est du HTML : on en tire du texte.
 *
 * Les images et les sons partent - ils ne sont pas importés, et laisser `[sound:03f.mp3]` au
 * verso d'une carte est pire que de ne rien laisser. Les formules changent de notation :
 * Anki écrit `[latex]`, `[$]` ou les délimiteurs de MathJax, Micabo écrit `$…$`, et c'est
 * cette graphie que KaTeX compose ici.
 */
export function cleanField(field: string): string {
  return field
    .replace(/\[sound:[^\]]*\]/gi, " ")
    .replace(/<img\b[^>]*>/gi, " ")
    .replace(/\[\$\$\]([\s\S]*?)\[\/\$\$\]/gi, (_match, body: string) => `$${body.trim()}$`)
    .replace(/\[\$\]([\s\S]*?)\[\/\$\]/gi, (_match, body: string) => `$${body.trim()}$`)
    .replace(/\[latex\]([\s\S]*?)\[\/latex\]/gi, (_match, body: string) => `$${body.trim()}$`)
    .replace(/\\\(([\s\S]*?)\\\)/g, (_match, body: string) => `$${body.trim()}$`)
    .replace(/\\\[([\s\S]*?)\\\]/g, (_match, body: string) => `$${body.trim()}$`)
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/(?:div|p|li|tr|h[1-6])>/gi, "\n")
    .replace(/<li\b[^>]*>/gi, "\n· ")
    .replace(/<(?:script|style)\b[^>]*>[\s\S]*?<\/(?:script|style)>/gi, " ")
    .replace(/<[^>]*>/g, "")
    .replace(/&nbsp;/gi, " ")
    .replace(/&(amp|lt|gt|quot|apos|#39);/gi, (entity) => ENTITIES[entity.toLowerCase()] ?? entity)
    .replace(/&#(\d+);/g, (_match, code: string) => safeCharacter(Number(code)))
    .replace(/&#x([0-9a-f]+);/gi, (_match, code: string) => safeCharacter(parseInt(code, 16)))
    .replace(/\u00a0/g, " ")
    .replace(/[ \t]+/g, " ")
    .replace(/ ?\n ?/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

const ENTITIES: Record<string, string> = {
  "&amp;": "&",
  "&lt;": "<",
  "&gt;": ">",
  "&quot;": '"',
  "&apos;": "'",
  "&#39;": "'",
};

function safeCharacter(code: number): string {
  if (!Number.isFinite(code) || code < 32 || code > 0x10ffff) return " ";
  return String.fromCodePoint(code);
}

function cut(value: string): string {
  return value.length > MAX_SIDE ? `${value.slice(0, MAX_SIDE - 1).trimEnd()}…` : value;
}

/**
 * L'autre sortie d'Anki : l'export en texte.
 *
 * Une ligne par note, des champs séparés par une tabulation, et des directives en tête
 * (`#separator:`, `#deck column:`) qu'il faut lire pour ne pas prendre le paquet pour une
 * réponse. C'est le format que produit « Notes en texte brut », et c'est le seul que les
 * gens arrivent à sortir d'un Anki qui refuse d'exporter un `.apkg`.
 */
export function readAnkiTextExport(source: string, fileName = ""): AnkiPackage {
  const body: string[] = [];
  let separator: string | null = null;
  let deckColumn = -1;
  let tagsColumn = -1;

  for (const line of source.split(/\r?\n/)) {
    if (line.startsWith("#")) {
      const directive = /^#\s*([^:]+):\s*(.*)$/.exec(line);
      if (!directive) continue;
      const key = directive[1]!.trim().toLowerCase();
      const value = directive[2]!.trim();
      if (key === "separator") separator = separatorFor(value);
      if (key === "deck column") deckColumn = Number(value) - 1;
      if (key === "tags column") tagsColumn = Number(value) - 1;
      continue;
    }
    if (line.trim().length === 0) continue;
    body.push(line);
  }

  const cut = separator ?? sniffSeparator(body);
  const rows = body.map((line) => line.split(cut));

  const suggested = fileName.replace(/\.[^.]+$/, "").trim();
  const cards: AnkiCard[] = [];
  const counts = new Map<string, number>();
  let skipped = 0;

  for (const row of rows) {
    const deck = deckColumn >= 0 ? deckName(row[deckColumn] ?? "") : suggested;
    const tags = tagsColumn >= 0 ? (row[tagsColumn] ?? "").split(/\s+/).filter(Boolean) : [];
    const fields = row
      .filter((_value, index) => index !== deckColumn && index !== tagsColumn)
      .map((value) => cleanField(value));

    const written = notesToCards(fields, deck || suggested, tags);
    if (written.length === 0) {
      skipped += 1;
      continue;
    }
    for (const card of written) {
      cards.push(card);
      counts.set(card.deck, (counts.get(card.deck) ?? 0) + 1);
      if (cards.length >= ANKI_CARD_LIMIT) break;
    }
    if (cards.length >= ANKI_CARD_LIMIT) break;
  }

  if (cards.length === 0) throw new AnkiError("empty");

  const decks = [...counts.entries()]
    .map(([name, count]) => ({ name, cards: count }))
    .sort((left, right) => right.cards - left.cards || left.name.localeCompare(right.name));

  return {
    title: decks.length === 1 ? decks[0]!.name || suggested : suggested,
    decks,
    cards,
    skipped,
  };
}

/**
 * Le séparateur, quand le fichier ne le déclare pas.
 *
 * Anki écrit toujours l'en-tête `#separator:`, mais un fichier repassé par un tableur ne
 * l'a plus, et la tabulation devient une virgule sans que rien ne le dise. On garde donc le
 * caractère qui coupe **le plus de lignes en au moins deux morceaux** - une virgule qui
 * n'apparaît que dans une phrase sur dix ne gagne pas contre une tabulation partout.
 */
function sniffSeparator(lines: string[]): string {
  const sample = lines.slice(0, 40);
  let best = "\t";
  let bestScore = 0;

  for (const candidate of ["\t", ";", ",", "|"]) {
    const score = sample.filter((line) => line.split(candidate).length >= 2).length;
    if (score > bestScore) {
      best = candidate;
      bestScore = score;
    }
  }

  return best;
}

function separatorFor(value: string): string {
  const named: Record<string, string> = {
    tab: "\t",
    comma: ",",
    semicolon: ";",
    space: " ",
    pipe: "|",
    colon: ":",
  };
  return named[value.toLowerCase()] ?? (value.length > 0 ? value : "\t");
}
