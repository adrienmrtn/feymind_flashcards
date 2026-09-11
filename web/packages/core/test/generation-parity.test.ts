/**
 * **Le test qui empêche les deux clients d'écrire deux fiches.**
 *
 * Une fiche est écrite au même endroit pour tout le monde : l'Edge Function `generate-course`,
 * son prompt système et son code couleur. Ce qui pouvait diverger, c'est ce que chaque client
 * lui envoie — et ça a divergé : le site envoyait les consignes libres de l'étudiant, l'app
 * non, donc à consigne égale les deux ne rendaient pas la même fiche, sans que rien ne le
 * signale.
 *
 * Ici on relit le Swift et le TypeScript du site, et on compare les champs envoyés. Une
 * divergence tombe au prochain `pnpm test`.
 *
 * Un seul champ reste asymétrique, et c'est voulu : `subject`. L'app le connaît quand elle
 * **réécrit** la fiche d'un cours déjà rangé ; à l'import, ni l'un ni l'autre ne le sait, et
 * c'est la fonction qui le devine sur le texte.
 */

import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, "../../../..");

const iosService = readFileSync(
  resolve(repoRoot, "Micabo/Services/SupabaseAIService.swift"),
  "utf8",
);
const webImport = readFileSync(resolve(repoRoot, "web/lib/import/create-sheet.ts"), "utf8");
const prompt = readFileSync(
  resolve(repoRoot, "supabase/functions/generate-course/prompt.ts"),
  "utf8",
);

/** Les clés d'un littéral, telles qu'elles sont écrites entre l'ouverture et la fermeture. */
function keysBetween(source: string, start: string, end: string, pattern: RegExp): string[] {
  const from = source.indexOf(start);
  expect(from, `\`${start}\` introuvable`).toBeGreaterThan(-1);
  const to = source.indexOf(end, from);
  expect(to, `fin de bloc introuvable après \`${start}\``).toBeGreaterThan(from);
  return [...source.slice(from, to).matchAll(pattern)].map((match) => match[1]!);
}

const iosKeys = keysBetween(
  iosService,
  'let payload: [String: Any] = [',
  'post("generate-course"',
  /"([a-zA-Z]+)":/g,
);

const webKeys = keysBetween(
  webImport,
  'functions.invoke("generate-course"',
  "if (error) return",
  // Le corps est écrit à six espaces, et une clé peut être abrégée : `text,` vaut `text: text`.
  /^ {6}([a-zA-Z]+)[,:]/gm,
);

describe("la fiche, des deux côtés", () => {
  it("passe par la même Edge Function", () => {
    expect(iosService).toContain('post("generate-course"');
    expect(webImport).toContain('functions.invoke("generate-course"');
  });

  it("envoie les mêmes champs", () => {
    expect(webKeys.length).toBeGreaterThan(5);
    for (const key of webKeys) {
      expect(iosKeys, `l'app n'envoie pas \`${key}\``).toContain(key);
    }
    // `subject` mis à part : voir l'en-tête.
    for (const key of iosKeys.filter((name) => name !== "subject")) {
      expect(webKeys, `le site n'envoie pas \`${key}\``).toContain(key);
    }
  });

  it("porte les consignes libres de l'étudiant des deux côtés", () => {
    // C'était la divergence : un champ que le site remplissait et que l'app ignorait.
    expect(iosKeys).toContain("instructions");
    expect(webKeys).toContain("instructions");
  });

  it("borne le texte et les consignes au même endroit", () => {
    for (const source of [iosService, webImport]) {
      expect(source).toMatch(/60[_ ]?000/);
      expect(source).toMatch(/2[_ ]?000/);
    }
    expect(prompt).toContain("MAX_INSTRUCTIONS = 2_000");
  });
});
