/**
 * ICU réduit : `{name}` et `{count, plural, one {…} other {…}}`.
 *
 * Les branches sont celles d'`Intl.PluralRules` : `zero`, `one`, `two`, `few`, `many`,
 * `other`, plus les valeurs exactes (`=0`). L'anglais et le français n'ont besoin que de
 * `one` / `other` ; le russe, le polonais, le tchèque, le croate… écrivent aussi `few` et
 * `many`, l'arabe les six. Une catégorie absente retombe sur `other`. `#` dans une branche
 * est le nombre formaté dans la locale, et une branche peut contenir des jetons `{name}`.
 *
 * `locale` est une locale `Intl` (`pt-BR`, `sr-Latn-RS`) : `makeTranslator` passe le `bcp47`.
 */

const PLURAL_START = /\{(\w+),\s*plural,/g;
const SELECTOR = /^(=\d+|zero|one|two|few|many|other)/;
const TOKEN = /\{(\w+)\}/g;

type PluralBlock = { end: number; branches: Map<string, string> };

/** Lit les branches d'un bloc pluriel à partir de `from` (juste après `plural,`). */
function readPluralBlock(template: string, from: number): PluralBlock | null {
  const branches = new Map<string, string>();
  let index = from;
  for (;;) {
    while (index < template.length && /\s/.test(template[index]!)) index += 1;
    if (index >= template.length) return null;
    if (template[index] === "}") return branches.size > 0 ? { end: index + 1, branches } : null;

    const selector = SELECTOR.exec(template.slice(index))?.[1];
    if (!selector) return null;
    index += selector.length;
    while (index < template.length && /\s/.test(template[index]!)) index += 1;
    if (template[index] !== "{") return null;

    let depth = 1;
    const start = index + 1;
    index = start;
    while (index < template.length && depth > 0) {
      const char = template[index];
      if (char === "{") depth += 1;
      else if (char === "}") depth -= 1;
      index += 1;
    }
    if (depth !== 0) return null;
    branches.set(selector, template.slice(start, index - 1));
  }
}

function pluralRules(locale: string): Intl.PluralRules {
  try {
    return new Intl.PluralRules(locale);
  } catch {
    return new Intl.PluralRules("en");
  }
}

function numberFormat(locale: string): Intl.NumberFormat {
  try {
    return new Intl.NumberFormat(locale);
  } catch {
    return new Intl.NumberFormat("en");
  }
}

function replacePlurals(
  template: string,
  vars: Record<string, string | number>,
  locale: string,
): string {
  let out = "";
  let cursor = 0;
  PLURAL_START.lastIndex = 0;
  for (let match = PLURAL_START.exec(template); match; match = PLURAL_START.exec(template)) {
    const block = readPluralBlock(template, PLURAL_START.lastIndex);
    if (!block) continue;

    const raw = vars[match[1]!];
    const count = typeof raw === "number" ? raw : Number(raw);
    const n = Number.isFinite(count) ? count : 0;
    const category = pluralRules(locale).select(n);
    const branch =
      block.branches.get(`=${n}`) ?? block.branches.get(category) ?? block.branches.get("other") ?? "";

    out += template.slice(cursor, match.index) + branch.replace(/#/g, numberFormat(locale).format(n));
    cursor = block.end;
    PLURAL_START.lastIndex = block.end;
  }
  return out + template.slice(cursor);
}

export function formatMessage(
  template: string,
  vars: Record<string, string | number> = {},
  locale = "en",
): string {
  const withPlurals = replacePlurals(template, vars, locale);

  return withPlurals.replace(TOKEN, (_all, key) => {
    const value = vars[key];
    return value === undefined || value === null ? "" : String(value);
  });
}

export type MessageTree = { [key: string]: string | MessageTree };

export function lookup(tree: MessageTree, path: string): string | undefined {
  const parts = path.split(".");
  let node: string | MessageTree | undefined = tree;
  for (const part of parts) {
    if (!node || typeof node === "string") return undefined;
    node = node[part];
  }
  return typeof node === "string" ? node : undefined;
}
