import { existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { LESSON_ICONS } from "@micabo/core";
import { describe, expect, it } from "vitest";

import { ICON_3D_IDS, ICON_FALLBACKS, iconSrc, missingCatalogImages, resolveIconId } from "./icons";

const here = dirname(fileURLToPath(import.meta.url));
const publicDir = resolve(here, "../../public");
const swift = resolve(here, "../../..", "Micabo/DesignSystem/MicaboIcon.swift");

describe("les icônes 3D", () => {
  it("ont chacune leur image dans public/icons3d", () => {
    for (const id of ICON_3D_IDS) {
      expect(existsSync(resolve(publicDir, iconSrc(id).slice(1))), id).toBe(true);
    }
  });

  it("couvrent tout ce que le modèle peut choisir", () => {
    expect(missingCatalogImages()).toEqual([]);
    expect(LESSON_ICONS.length).toBeGreaterThan(20);
  });

  it("portent les mêmes identifiants que `MicaboIcon` dans l'app", async () => {
    const { readFileSync } = await import("node:fs");
    const source = readFileSync(swift, "utf8");
    // Les cas de la base : `case globe = "globe"`. Les cas hors base n'ont pas de valeur brute.
    const inBase = [...source.matchAll(/case \w+ = "([a-z-]+)"/g)].map((match) => match[1]);
    expect([...inBase].sort()).toEqual([...ICON_3D_IDS].sort());
    const outside = [...source.matchAll(/^\s{4}case ([a-z]+)$/gm)].map((match) => match[1]);
    expect([...outside].sort()).toEqual(Object.keys(ICON_FALLBACKS).sort());
  });

  it("ramènent un nom inconnu au livre", () => {
    expect(resolveIconId("globe")).toBe("globe");
    expect(resolveIconId(" Globe ")).toBe("globe");
    expect(resolveIconId("audio")).toBe("audio");
    expect(resolveIconId("licorne")).toBe("livre-ouvert");
    expect(resolveIconId(null)).toBe("livre-ouvert");
  });
});
