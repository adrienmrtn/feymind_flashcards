import { assertEquals } from "jsr:@std/assert@1";
import { normalizeSymbol, PATH_SYMBOLS, uniqueSymbols } from "./symbols.ts";

Deno.test("le catalogue serveur est celui de l'app, dans le même ordre", async () => {
  const swift = await Deno.readTextFile(
    new URL("../../../Micabo/DesignSystem/PathSymbol.swift", import.meta.url),
  );
  const block = swift.slice(swift.indexOf("static let catalog"), swift.indexOf("static let fallback"));
  const ids = [...block.matchAll(/"([^"]+)"/g)].map((m) => m[1]);
  assertEquals(ids, PATH_SYMBOLS.map((symbol) => symbol.id));
});

Deno.test("un pictogramme par thème, tous différents, même quand le modèle se répète", () => {
  const symbols = uniqueSymbols(["flag", "flag", "inconnu", "", "map"]);
  assertEquals(symbols[0], "flag");
  assertEquals(new Set(symbols).size, symbols.length);
  assertEquals(symbols[4], "map");
  assertEquals(normalizeSymbol(" Atom "), "atom");
  assertEquals(normalizeSymbol("rien"), "");
  assertEquals(new Set(PATH_SYMBOLS.map((s) => s.id)).size, PATH_SYMBOLS.length, "le catalogue n'a pas de doublon");
});
