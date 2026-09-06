/**
 * Lire une base SQLite, en lecture seule, dans l'onglet.
 *
 * ## Pourquoi à la main
 *
 * La collection d'Anki *est* une base SQLite : il n'y a pas de format d'échange, le `.apkg`
 * emporte le fichier tel quel. Le réflexe serait `sql.js`, donc un mégaoctet et demi de
 * WebAssembly pour exécuter des requêtes qu'on n'écrit pas : on ne fait ici que **relire
 * quatre tables entières**, sans jointure, sans filtre et sans index.
 *
 * Le format de fichier est documenté et figé depuis 2004. Ce module en implémente la part
 * qui sert : l'en-tête, le catalogue (`sqlite_master`), la descente d'un arbre B, les pages
 * de débordement et le codage des enregistrements. Pas d'écriture, pas de journal, pas de
 * `WAL` - un fichier sorti d'une archive est un instantané cohérent.
 *
 * ## Le piège qui coûte une heure
 *
 * Une colonne déclarée `integer primary key` **n'est pas stockée** : elle est un alias du
 * `rowid`, et l'enregistrement porte un `NULL` à sa place. Les identifiants de notes d'Anki
 * sont exactement ça. Sans la substitution faite plus bas, `notes.id` revient vide et rien
 * ne se relie à rien.
 */

export type SqliteValue = null | number | string | Uint8Array;

export interface SqliteTable {
  columns: string[];
  rows: SqliteValue[][];
}

export class SqliteError extends Error {
  constructor(readonly code: "notSqlite" | "corrupt") {
    super(code);
  }
}

const MAGIC = "SQLite format 3\u0000";

export function looksLikeSqlite(data: Uint8Array): boolean {
  if (data.length < 100) return false;
  return new TextDecoder("latin1").decode(data.subarray(0, 16)) === MAGIC;
}

export function openSqlite(data: Uint8Array): SqliteDatabase {
  if (!looksLikeSqlite(data)) throw new SqliteError("notSqlite");

  const declared = u16(data, 16);
  const pageSize = declared === 1 ? 65_536 : declared;
  if (pageSize < 512 || (pageSize & (pageSize - 1)) !== 0) throw new SqliteError("corrupt");

  return new SqliteDatabase(data, pageSize, pageSize - data[20]!);
}

interface SchemaEntry {
  name: string;
  rootPage: number;
  sql: string;
}

export class SqliteDatabase {
  private readonly schema: Map<string, SchemaEntry>;

  constructor(
    private readonly data: Uint8Array,
    private readonly pageSize: number,
    private readonly usableSize: number,
  ) {
    this.schema = this.readSchema();
  }

  tableNames(): string[] {
    return [...this.schema.keys()];
  }

  has(table: string): boolean {
    return this.schema.has(table.toLowerCase());
  }

  /**
   * Toutes les lignes d'une table, dans l'ordre de l'arbre.
   *
   * `null` quand la table n'existe pas : les deux schémas d'Anki n'ont pas les mêmes tables,
   * et c'est la présence de `decks` qui distingue l'ancien du nouveau.
   */
  read(table: string): SqliteTable | null {
    const entry = this.schema.get(table.toLowerCase());
    if (!entry) return null;

    const columns = tableColumns(entry.sql);
    const rowidColumn = rowidAlias(entry.sql, columns);
    const rows: SqliteValue[][] = [];

    for (const cell of this.cells(entry.rootPage)) {
      const values = decodeRecord(cell.payload);
      // Les colonnes ajoutées par un `alter table` ne sont pas réécrites dans les
      // enregistrements existants : la ligne est plus courte que le schéma.
      while (values.length < columns.length) values.push(null);
      if (rowidColumn >= 0 && cell.rowid !== null && values[rowidColumn] === null) {
        values[rowidColumn] = cell.rowid;
      }
      rows.push(values.slice(0, columns.length));
    }

    return { columns, rows };
  }

  /** Une table sous forme de dictionnaires, quand l'ordre des colonnes ne sert à rien. */
  readRecords(table: string): Record<string, SqliteValue>[] | null {
    const read = this.read(table);
    if (!read) return null;
    return read.rows.map((row) => {
      const record: Record<string, SqliteValue> = {};
      read.columns.forEach((column, index) => {
        record[column] = row[index] ?? null;
      });
      return record;
    });
  }

  private readSchema(): Map<string, SchemaEntry> {
    const schema = new Map<string, SchemaEntry>();

    // `sqlite_master(type, name, tbl_name, rootpage, sql)` : le catalogue a toujours la
    // même forme, il n'y a donc rien à analyser pour le lire.
    for (const cell of this.cells(1)) {
      const values = decodeRecord(cell.payload);
      const kind = asText(values[0]);
      const name = asText(values[1]);
      const rootPage = asNumber(values[3]);
      const sql = asText(values[4]);
      if (kind !== "table" || !name || !rootPage) continue;
      schema.set(name.toLowerCase(), { name, rootPage, sql });
    }

    return schema;
  }

  /**
   * Les cellules d'un arbre, feuilles comprises.
   *
   * La descente est itérative : un arbre profond sur une pile d'appels finirait par déborder,
   * et un paquet Anki de trente mille notes est exactement le cas où ça arrive.
   */
  private *cells(rootPage: number): Generator<{ rowid: number | null; payload: Uint8Array }> {
    const stack: number[] = [rootPage];
    const seen = new Set<number>();

    while (stack.length > 0) {
      const pageNumber = stack.pop()!;
      if (pageNumber < 1 || seen.has(pageNumber)) continue;
      seen.add(pageNumber);

      const start = (pageNumber - 1) * this.pageSize;
      if (start < 0 || start >= this.data.length) continue;
      const header = start + (pageNumber === 1 ? 100 : 0);
      const type = this.data[header];
      if (type === undefined) continue;

      const cellCount = u16(this.data, header + 3);
      const interior = type === 0x02 || type === 0x05;
      const pointers = header + (interior ? 12 : 8);
      const children: number[] = [];

      if (interior) children.push(u32(this.data, header + 8));

      for (let index = 0; index < cellCount; index += 1) {
        const offset = u16(this.data, pointers + index * 2);
        if (offset === 0) continue;
        let at = start + offset;

        if (type === 0x05) {
          // Arbre de table, page interne : un pointeur, puis la clé qu'on n'utilise pas.
          children.push(u32(this.data, at));
          continue;
        }

        if (type === 0x02) {
          // Arbre d'index, page interne : elle porte aussi une clé, donc une ligne d'une
          // table `without rowid`.
          children.push(u32(this.data, at));
          at += 4;
          const size = varint(this.data, at);
          yield { rowid: null, payload: this.payload(size.value, size.next, true) };
          continue;
        }

        if (type === 0x0d) {
          const size = varint(this.data, at);
          const key = varint(this.data, size.next);
          yield { rowid: key.value, payload: this.payload(size.value, key.next, false) };
          continue;
        }

        if (type === 0x0a) {
          const size = varint(this.data, at);
          yield { rowid: null, payload: this.payload(size.value, size.next, true) };
        }
      }

      for (let index = children.length - 1; index >= 0; index -= 1) {
        stack.push(children[index]!);
      }
    }
  }

  /**
   * Le contenu d'une cellule, débordement recousu.
   *
   * Une page ne garde qu'un début de charge utile quand elle est longue, et le reste part
   * dans une chaîne de pages. Les seuils viennent de la documentation du format et diffèrent
   * entre table et index : les recopier faux donne des champs tronqués en silence, ce qui
   * est pire qu'une erreur.
   */
  private payload(size: number, start: number, isIndex: boolean): Uint8Array {
    const maxLocal = isIndex
      ? Math.floor(((this.usableSize - 12) * 64) / 255) - 23
      : this.usableSize - 35;

    if (size <= maxLocal) return this.data.subarray(start, start + size);

    const minLocal = Math.floor(((this.usableSize - 12) * 32) / 255) - 23;
    let local = minLocal + ((size - minLocal) % (this.usableSize - 4));
    if (local > maxLocal) local = minLocal;

    const out = new Uint8Array(size);
    out.set(this.data.subarray(start, start + local), 0);
    let written = local;
    let next = u32(this.data, start + local);

    while (next > 0 && written < size) {
      const page = (next - 1) * this.pageSize;
      if (page + 4 > this.data.length) break;
      const take = Math.min(this.usableSize - 4, size - written);
      out.set(this.data.subarray(page + 4, page + 4 + take), written);
      written += take;
      next = u32(this.data, page);
    }

    return out;
  }
}

/** Le codage des enregistrements : un en-tête de types, puis les valeurs bout à bout. */
export function decodeRecord(payload: Uint8Array): SqliteValue[] {
  if (payload.length === 0) return [];

  const head = varint(payload, 0);
  const headerEnd = Math.min(head.value, payload.length);
  const types: number[] = [];
  let cursor = head.next;

  while (cursor < headerEnd) {
    const type = varint(payload, cursor);
    cursor = type.next;
    types.push(type.value);
  }

  const values: SqliteValue[] = [];
  let body = headerEnd;

  for (const type of types) {
    if (type === 0) {
      values.push(null);
      continue;
    }
    if (type === 8) {
      values.push(0);
      continue;
    }
    if (type === 9) {
      values.push(1);
      continue;
    }
    if (type >= 1 && type <= 6) {
      const width = type === 5 ? 6 : type === 6 ? 8 : type;
      values.push(signedInteger(payload, body, width));
      body += width;
      continue;
    }
    if (type === 7) {
      values.push(readFloat(payload, body));
      body += 8;
      continue;
    }
    if (type === 10 || type === 11) {
      values.push(null);
      continue;
    }

    const length = Math.max(0, (type - (type % 2 === 0 ? 12 : 13)) / 2);
    const slice = payload.subarray(body, body + length);
    values.push(type % 2 === 0 ? slice.slice() : new TextDecoder("utf-8").decode(slice));
    body += length;
  }

  return values;
}

/**
 * Les noms de colonnes, lus dans le `create table`.
 *
 * Il n'y a pas d'autre source : le fichier ne stocke que le texte de la requête. On coupe
 * donc aux virgules de premier niveau, en tenant compte des parenthèses et des guillemets,
 * et on écarte les contraintes de table, qui ne sont pas des colonnes.
 */
export function tableColumns(sql: string): string[] {
  const open = sql.indexOf("(");
  const close = sql.lastIndexOf(")");
  if (open < 0 || close < open) return [];

  return splitDefinitions(sql.slice(open + 1, close))
    .filter((part) => !isTableConstraint(part))
    .map(columnName)
    .filter((name): name is string => Boolean(name));
}

/** L'index de la colonne qui est le `rowid`, ou -1. Voir l'en-tête du module. */
function rowidAlias(sql: string, columns: string[]): number {
  const open = sql.indexOf("(");
  const close = sql.lastIndexOf(")");
  if (open < 0 || close < open) return -1;

  const definitions = splitDefinitions(sql.slice(open + 1, close)).filter(
    (part) => !isTableConstraint(part),
  );

  for (const definition of definitions) {
    if (!/\binteger\b/i.test(definition) || !/\bprimary\s+key\b/i.test(definition)) continue;
    const name = columnName(definition);
    if (!name) continue;
    const index = columns.indexOf(name);
    if (index >= 0) return index;
  }

  return -1;
}

function splitDefinitions(body: string): string[] {
  const parts: string[] = [];
  let depth = 0;
  let quote: string | null = null;
  let current = "";

  for (const character of body) {
    if (quote) {
      current += character;
      if (character === quote) quote = null;
      continue;
    }
    if (character === '"' || character === "'" || character === "`") {
      quote = character;
      current += character;
      continue;
    }
    if (character === "(") depth += 1;
    if (character === ")") depth -= 1;
    if (character === "," && depth === 0) {
      parts.push(current.trim());
      current = "";
      continue;
    }
    current += character;
  }

  if (current.trim().length > 0) parts.push(current.trim());
  return parts;
}

const TABLE_CONSTRAINTS = /^(constraint|primary\s+key|unique|check|foreign\s+key)\b/i;

function isTableConstraint(definition: string): boolean {
  return TABLE_CONSTRAINTS.test(definition.trim());
}

function columnName(definition: string): string | null {
  const trimmed = definition.trim();
  if (trimmed.length === 0) return null;

  const quote = trimmed[0]!;
  if (quote === '"' || quote === "'" || quote === "`") {
    const end = trimmed.indexOf(quote, 1);
    return end > 1 ? trimmed.slice(1, end) : null;
  }
  if (quote === "[") {
    const end = trimmed.indexOf("]");
    return end > 1 ? trimmed.slice(1, end) : null;
  }

  const bare = /^[A-Za-z_][A-Za-z0-9_$]*/.exec(trimmed);
  return bare ? bare[0] : null;
}

/**
 * Entier de longueur variable, gros-boutiste.
 *
 * Huit octets à sept bits utiles, puis un neuvième qui en donne huit : c'est le codage du
 * format, et le neuvième octet est le seul qui ne suive pas la règle des autres.
 */
export function varint(data: Uint8Array, offset: number): { value: number; next: number } {
  let value = 0;

  for (let index = 0; index < 8; index += 1) {
    const byte = data[offset + index];
    if (byte === undefined) return { value, next: offset + index };
    value = value * 128 + (byte & 0x7f);
    if ((byte & 0x80) === 0) return { value, next: offset + index + 1 };
  }

  return { value: value * 256 + (data[offset + 8] ?? 0), next: offset + 9 };
}

function signedInteger(data: Uint8Array, offset: number, width: number): number {
  let value = 0;
  for (let index = 0; index < width; index += 1) {
    value = value * 256 + (data[offset + index] ?? 0);
  }
  const limit = 2 ** (width * 8 - 1);
  return value >= limit ? value - limit * 2 : value;
}

function readFloat(data: Uint8Array, offset: number): number {
  const view = new DataView(new ArrayBuffer(8));
  for (let index = 0; index < 8; index += 1) view.setUint8(index, data[offset + index] ?? 0);
  return view.getFloat64(0, false);
}

export function asText(value: SqliteValue | undefined): string {
  if (typeof value === "string") return value;
  if (typeof value === "number") return String(value);
  if (value instanceof Uint8Array) return new TextDecoder("utf-8").decode(value);
  return "";
}

export function asNumber(value: SqliteValue | undefined): number {
  if (typeof value === "number") return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

function u16(data: Uint8Array, offset: number): number {
  return ((data[offset] ?? 0) << 8) | (data[offset + 1] ?? 0);
}

function u32(data: Uint8Array, offset: number): number {
  return (
    ((data[offset] ?? 0) * 0x1000000 +
      ((data[offset + 1] ?? 0) << 16) +
      ((data[offset + 2] ?? 0) << 8) +
      (data[offset + 3] ?? 0)) >>>
    0
  );
}
