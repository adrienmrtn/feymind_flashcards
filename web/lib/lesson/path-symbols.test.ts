import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { PATH_SYMBOLS } from "@micabo/core";
import { describe, expect, it } from "vitest";

import { PATH_SYMBOL_ICONS, pathSymbolIcon } from "./path-symbols";

const here = dirname(fileURLToPath(import.meta.url));
const pathLayout = readFileSync(
  resolve(here, "../../..", "Micabo/Models/PathLayout.swift"),
  "utf8",
);

describe("les pictogrammes du chemin", () => {
  it("ont tous une icône lucide", () => {
    for (const symbol of PATH_SYMBOLS) {
      expect(PATH_SYMBOL_ICONS[symbol.id], symbol.id).toBeDefined();
    }
  });

  it("dessinent aussi les ronds que le chemin pose lui-même", () => {
    // `PathLayout.checkpointSymbols`, l'Intro et le Quiz final, tels que l'app les nomme.
    const checkpoints = pathLayout.match(/checkpointSymbols = \[([^\]]+)\]/)?.[1] ?? "";
    const names = [...checkpoints.matchAll(/"([a-z.]+)"/g)].map((match) => match[1]!);
    expect(names.length).toBeGreaterThan(3);
    for (const name of [...names, "play.fill", "trophy"]) {
      expect(PATH_SYMBOL_ICONS[name], name).toBeDefined();
    }
  });

  it("retombent sur l'ampoule", () => {
    expect(pathSymbolIcon("licorne")).toBe(PATH_SYMBOL_ICONS.lightbulb);
    expect(pathSymbolIcon(undefined)).toBe(PATH_SYMBOL_ICONS.lightbulb);
    expect(pathSymbolIcon(" Atom ")).toBe(PATH_SYMBOL_ICONS.atom);
  });
});
