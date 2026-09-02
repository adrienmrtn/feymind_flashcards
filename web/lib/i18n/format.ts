/**
 * ICU réduit : `{name}` et `{count, plural, one {…} other {…}}`.
 *
 * Assez pour le français, l'allemand, l'espagnol et le turc (one / other).
 * `#` dans une branche plurielle est le nombre formaté dans la locale.
 */

const PLURAL =
  /\{(\w+),\s*plural,\s*one\s*\{([\s\S]*?)\}\s*other\s*\{([\s\S]*?)\}\}/g;
const TOKEN = /\{(\w+)\}/g;

export function formatMessage(
  template: string,
  vars: Record<string, string | number> = {},
  locale = "fr",
): string {
  const withPlurals = template.replace(PLURAL, (_all, key, one, other) => {
    const raw = vars[key];
    const count = typeof raw === "number" ? raw : Number(raw);
    const n = Number.isFinite(count) ? count : 0;
    const branch = new Intl.PluralRules(locale).select(n) === "one" ? one : other;
    const formatted = new Intl.NumberFormat(locale).format(n);
    return branch.replace(/#/g, formatted);
  });

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
