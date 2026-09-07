import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import {
  KNOWN_DOMAINS,
  TLD_TYPOS,
  UNDELIVERABLE_DOMAINS,
  UNDELIVERABLE_TLDS,
} from "../web/lib/auth/email.ts";
import { de } from "../web/lib/i18n/catalogs/de.ts";
import { es } from "../web/lib/i18n/catalogs/es.ts";
import { fr } from "../web/lib/i18n/catalogs/fr.ts";
import { tr } from "../web/lib/i18n/catalogs/tr.ts";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const outDir = join(root, "Micabo/Services/I18n/Generated");
const authOutDir = join(root, "Micabo/Services/Auth/Generated");

function flatten(tree: Record<string, unknown>, prefix = "", into: Record<string, string> = {}) {
  for (const [key, value] of Object.entries(tree)) {
    const path = prefix ? `${prefix}.${key}` : key;
    if (value && typeof value === "object") flatten(value as Record<string, unknown>, path, into);
    else into[path] = String(value);
  }
  return into;
}

function swiftString(value: string) {
  return JSON.stringify(value);
}

function emitSwift(catalogs: Record<string, Record<string, string>>) {
  const locales = ["fr", "de", "es", "tr"] as const;
  const blocks = locales.map((locale) => {
    const entries = Object.entries(catalogs[locale])
      .map(([key, value]) => `        ${swiftString(key)}: ${swiftString(value)},`)
      .join("\n");
    return `    static let ${locale}: [String: String] = [\n${entries}\n    ]`;
  });

  return `// Généré depuis web/lib/i18n/catalogs. Ne pas éditer à la main.
// Relancer : node --experimental-strip-types scripts/export-i18n-catalogs.ts

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

/**
 * Les listes du garde-fou des adresses, recopiées en Swift.
 *
 * Elles sont générées et non retapées parce que c'est exactement la dérive entre les deux
 * plateformes qui a coûté un rebond : le site et l'iPhone tenaient chacun leur idée de
 * l'adresse des relecteurs d'Apple, et les deux étaient trop étroites. Une liste de
 * référence n'a qu'une source.
 */
function emitEmailSwift() {
  const list = (values: readonly string[]) =>
    values.map((value) => `        ${swiftString(value)},`).join("\n");
  const pairs = Object.entries(TLD_TYPOS)
    .map(([wrong, right]) => `        ${swiftString(wrong)}: ${swiftString(right)},`)
    .join("\n");

  return `// Généré depuis web/lib/auth/email.ts. Ne pas éditer à la main.
// Relancer : node --experimental-strip-types scripts/export-i18n-catalogs.ts

enum EmailReference {
    static let knownDomains: [String] = [
${list(KNOWN_DOMAINS)}
    ]

    static let knownDomainSet: Set<String> = Set(knownDomains)

    static let undeliverableTLDs: Set<String> = [
${list(UNDELIVERABLE_TLDS)}
    ]

    static let undeliverableDomains: Set<String> = [
${list(UNDELIVERABLE_DOMAINS)}
    ]

    static let tldTypos: [String: String] = [
${pairs}
    ]
}
`;
}

const catalogs = {
  fr: flatten(fr as unknown as Record<string, unknown>),
  de: flatten(de as unknown as Record<string, unknown>),
  es: flatten(es as unknown as Record<string, unknown>),
  tr: flatten(tr as unknown as Record<string, unknown>),
};

mkdirSync(outDir, { recursive: true });
writeFileSync(join(outDir, "SharedI18nCatalogs.swift"), emitSwift(catalogs));

mkdirSync(authOutDir, { recursive: true });
writeFileSync(join(authOutDir, "EmailReference.swift"), emitEmailSwift());

console.log(
  "écrit",
  Object.fromEntries(Object.entries(catalogs).map(([locale, table]) => [locale, Object.keys(table).length])),
  `+ ${KNOWN_DOMAINS.length} domaines connus`,
);
