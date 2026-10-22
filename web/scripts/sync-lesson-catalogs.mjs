import { readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

/**
 * **Les phrases de la leçon, du Swift au site.**
 *
 * Les textes de la refonte « parcours » (`lesson.*`) sont écrits dans l'app, dans les cinq
 * langues, dans `Micabo/Services/I18n/LessonI18nCatalogs.swift` : c'est là qu'ils se relisent
 * langue contre langue, et c'est là que `LessonI18nTests` vérifie qu'aucune table n'a de trou.
 * Le site dit les mêmes phrases : ce script les recopie dans
 * `lib/i18n/catalogs/lesson-<langue>.ts`, en arbre, comme le reste des catalogues.
 *
 * Le sens de la copie est l'inverse des autres catalogues (`scripts/export-i18n-catalogs.ts`
 * descend ceux du site vers l'iPhone), et c'est voulu : le lexique de la leçon est né dans
 * l'app. `lib/i18n/lesson-catalogs.test.ts` relit le Swift et échoue si une copie a dérivé.
 *
 *     node web/scripts/sync-lesson-catalogs.mjs
 */

const here = dirname(fileURLToPath(import.meta.url));
export const repoRoot = resolve(here, "../..");
export const SOURCE = resolve(repoRoot, "Micabo/Services/I18n/LessonI18nCatalogs.swift");
export const LOCALES = ["fr", "en", "de", "es", "tr"];

export function targetFor(locale) {
  return resolve(here, `../lib/i18n/catalogs/lesson-${locale}.ts`);
}

/** Une chaîne Swift entre guillemets, ramenée à sa valeur. */
function unquote(literal) {
  return literal
    .replace(/\\u\{([0-9a-fA-F]+)\}/g, (_all, hex) => String.fromCodePoint(parseInt(hex, 16)))
    .replace(/\\n/g, "\n")
    .replace(/\\t/g, "\t")
    .replace(/\\"/g, '"')
    .replace(/\\\\/g, "\\");
}

/** La table d'une langue : `static let fr: [String: String] = [ … ]`, clé par clé. */
export function parseTable(swift, locale) {
  const start = swift.indexOf(`static let ${locale}: [String: String] = [`);
  if (start < 0) throw new Error(`${SOURCE} : table « ${locale} » introuvable.`);
  const end = swift.indexOf("\n    ]", start);
  if (end < 0) throw new Error(`${SOURCE} : fin de la table « ${locale} » introuvable.`);
  const block = swift.slice(start, end);
  const entries = new Map();
  const line = /^\s*"((?:[^"\\]|\\.)*)":\s*"((?:[^"\\]|\\.)*)",?\s*$/gm;
  for (const match of block.matchAll(line)) {
    const key = unquote(match[1]);
    if (!key.startsWith("lesson.")) throw new Error(`${locale} : la clé « ${key} » ne commence pas par lesson.`);
    if (entries.has(key)) throw new Error(`${locale} : la clé « ${key} » est écrite deux fois.`);
    entries.set(key, unquote(match[2]));
  }
  if (entries.size === 0) throw new Error(`${SOURCE} : la table « ${locale} » est vide.`);
  return entries;
}

/** Les clés à plat, en arbre, sans le préfixe `lesson.` : le catalogue du site les range sous `lesson`. */
export function toTree(entries) {
  const tree = {};
  for (const [key, value] of entries) {
    const parts = key.slice("lesson.".length).split(".");
    let node = tree;
    for (const [index, part] of parts.entries()) {
      if (index === parts.length - 1) {
        if (typeof node[part] === "object") throw new Error(`« ${key} » est à la fois une phrase et un groupe.`);
        node[part] = value;
      } else {
        if (typeof node[part] === "string") throw new Error(`« ${key} » est à la fois une phrase et un groupe.`);
        node[part] ??= {};
        node = node[part];
      }
    }
  }
  return tree;
}

function emit(tree, depth) {
  const pad = "  ".repeat(depth);
  const lines = Object.entries(tree).map(([key, value]) => {
    const name = /^[A-Za-z_][A-Za-z0-9_]*$/.test(key) ? key : JSON.stringify(key);
    if (typeof value === "string") return `${pad}${name}: ${JSON.stringify(value)},`;
    return `${pad}${name}: {\n${emit(value, depth + 1)}\n${pad}},`;
  });
  return lines.join("\n");
}

export function moduleFor(locale, swift = readFileSync(SOURCE, "utf8")) {
  const tree = toTree(parseTable(swift, locale));
  const name = `lesson${locale[0].toUpperCase()}${locale.slice(1)}`;
  return `// Généré depuis Micabo/Services/I18n/LessonI18nCatalogs.swift par
// web/scripts/sync-lesson-catalogs.mjs. Ne pas éditer à la main : la phrase se change dans
// l'app, puis on relance le script.

export const ${name} = {
${emit(tree, 1)}
} as const;
`;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const swift = readFileSync(SOURCE, "utf8");
  for (const locale of LOCALES) {
    const target = targetFor(locale);
    const module = moduleFor(locale, swift);
    writeFileSync(target, module, "utf8");
    console.log(`Écrit ${target} (${parseTable(swift, locale).size} phrases)`);
  }
}
