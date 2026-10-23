/**
 * **Les langues des fiches, les mêmes que l'app.** On relit `ContentLanguage` dans le Swift et
 * `AppLocale` dans le Kotlin : une langue choisie sur le téléphone que le site ne connaîtrait pas
 * reviendrait ici comme une valeur inconnue, et le réglage la retomberait sur le pays sans rien dire.
 */

import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

import { CONTENT_LANGUAGES, LANGUAGE_LABELS, isContentLanguage, sheetLanguage } from "../src/onboarding/countries";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, "../../../..");

function swiftLanguages(): string[] {
  const source = readFileSync(resolve(repoRoot, "Micabo/Features/Onboarding/EducationStage.swift"), "utf8");
  const body = source.slice(source.indexOf("enum ContentLanguage"));
  const cases = body.slice(0, body.indexOf("var id")).matchAll(/case (\w+)(?: = "([^"]+)")?/g);
  return [...cases].map((match) => match[2] ?? match[1]!);
}

function androidLanguages(): string[] {
  const source = readFileSync(resolve(repoRoot, "android/app/src/main/java/com/micabo/app/i18n/AppLocale.kt"), "utf8");
  return [...source.matchAll(/^\s+[A-Z0-9]+\("[^"]+", "[^"]+", "([^"]+)"\)[,;]/gm)].map((match) => match[1]!);
}

describe("les langues des fiches", () => {
  it("sont les vingt-six de l'iPhone, dans le même ordre", () => {
    expect(CONTENT_LANGUAGES).toEqual(swiftLanguages());
    expect(CONTENT_LANGUAGES).toHaveLength(26);
  });

  it("couvrent celles qu'Android envoie au serveur", () => {
    for (const code of androidLanguages()) expect(isContentLanguage(code), code).toBe(true);
  });

  it("gardent les variantes régionales, et retombent sur le pays sinon", () => {
    expect(isContentLanguage("es-419")).toBe(true);
    expect(isContentLanguage("pt-BR")).toBe(true);
    expect(isContentLanguage("toString")).toBe(false);
    expect(sheetLanguage("da", "fr")).toBe("da");
    expect(sheetLanguage("zz", "de")).toBe("de");
    expect(LANGUAGE_LABELS.ar).toBe("العربية");
  });
});
