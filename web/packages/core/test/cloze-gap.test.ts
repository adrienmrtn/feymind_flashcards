/**
 * **Le trou d'une phrase, le même partout.** Le serveur l'écrit (`GAP`), l'iPhone et Android le
 * relisent (`ClozeGap.marker`, `GAP_MARK`) : un autre marqueur sur le site faisait de chaque carte
 * à trou une carte simple, et d'une carte à trou venue du téléphone une carte sans réponse.
 */

import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

import { CLOZE_GAP, hasClozeGap, normalizeClozeGap } from "../src/lesson/types";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, "../../../..");
const read = (path: string) => readFileSync(resolve(repoRoot, path), "utf8");

describe("le trou d'une phrase", () => {
  it("est celui du serveur, de l'iPhone et d'Android", () => {
    expect(read("supabase/functions/generate-lesson/schema.ts")).toContain(`export const GAP = "${CLOZE_GAP}";`);
    expect(read("Micabo/Models/Flashcard.swift")).toContain(`static let marker = "${CLOZE_GAP}"`);
    expect(read("android/app/src/main/java/com/micabo/app/data/CloudSync.kt")).toContain(`const val GAP_MARK = "${CLOZE_GAP}"`);
  });

  it("ramène les autres graphies à un seul trou", () => {
    expect(normalizeClozeGap("La ____ de Paris")).toBe("La … de Paris");
    expect(normalizeClozeGap("Un [...] et (…)")).toBe("Un … et …");
    expect(normalizeClozeGap("Deux ... ... blancs")).toBe("Deux … … blancs");
    expect(normalizeClozeGap("Collés __________")).toBe("Collés …");
    expect(hasClozeGap("Sans trou")).toBe(false);
    expect(hasClozeGap("Ancien ____ du site")).toBe(true);
  });
});
