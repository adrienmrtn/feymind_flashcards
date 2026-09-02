/**
 * Aplatit les catalogues web en JSON, pour que l'iPhone lise les mêmes phrases.
 */
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const locales = ["fr", "de", "es", "tr"];
const outDir = join(root, "Micabo/Services/I18n/Generated");

function extractObjectLiteral(source) {
  const assignment = source.search(/=\s*\{/);
  const start = assignment >= 0 ? source.indexOf("{", assignment) : source.indexOf("{");
  if (start < 0) throw new Error("pas d'objet");
  let depth = 0;
  let inString = false;
  let quote = "";
  let escaped = false;
  for (let index = start; index < source.length; index += 1) {
    const char = source[index];
    if (inString) {
      if (escaped) {
        escaped = false;
        continue;
      }
      if (char === "\\") {
        escaped = true;
        continue;
      }
      if (char === quote) inString = false;
      continue;
    }
    if (char === '"' || char === "'" || char === "`") {
      inString = true;
      quote = char;
      continue;
    }
    if (char === "{") depth += 1;
    if (char === "}") {
      depth -= 1;
      if (depth === 0) return source.slice(start, index + 1);
    }
  }
  throw new Error("objet non fermé");
}

function flatten(tree, prefix = "", into = {}) {
  for (const [key, value] of Object.entries(tree)) {
    const path = prefix ? `${prefix}.${key}` : key;
    if (value && typeof value === "object") flatten(value, path, into);
    else into[path] = String(value);
  }
  return into;
}

function swiftString(value) {
  return JSON.stringify(value);
}

function emitSwift(catalogs) {
  const blocks = locales.map((locale) => {
    const entries = Object.entries(catalogs[locale])
      .map(([key, value]) => `        ${swiftString(key)}: ${swiftString(value)},`)
      .join("\n");
    return `    static let ${locale}: [String: String] = [\n${entries}\n    ]`;
  });

  return `// Généré depuis web/lib/i18n/catalogs. Ne pas éditer à la main.
// Relancer : node scripts/export-i18n-catalogs.mjs

enum SharedI18nCatalogs {
${blocks.join("\n\n")}

    static func table(for locale: String) -> [String: String] {
        switch locale {
        case "de": de
        case "es": es
        case "tr": tr
        default: fr
        }
    }
}
`;
}

const catalogs = {};
for (const locale of locales) {
  const source = readFileSync(join(root, `web/lib/i18n/catalogs/${locale}.ts`), "utf8");
  const tree = Function(`"use strict"; return (${extractObjectLiteral(source)})`)();
  catalogs[locale] = flatten(tree);
}

mkdirSync(outDir, { recursive: true });
writeFileSync(join(outDir, "SharedI18nCatalogs.swift"), emitSwift(catalogs));
console.log(
  "écrit",
  Object.fromEntries(locales.map((locale) => [locale, Object.keys(catalogs[locale]).length])),
);
