import { assertEquals } from "jsr:@std/assert@1";
import { DEFAULT_ICON, LESSON_ICONS, normalizeIcon } from "./icons.ts";

Deno.test("le catalogue serveur est celui de l'app, dans le même ordre", async () => {
  const swift = await Deno.readTextFile(
    new URL("../../../Micabo/DesignSystem/MicaboIcon.swift", import.meta.url),
  );
  // Les cas Swift : `case book = "livre-ouvert"` → livre-ouvert.
  const rawValues = new Map<string, string>();
  for (const match of swift.matchAll(/case (\w+) = "([^"]+)"/g)) {
    rawValues.set(match[1]!, match[2]!);
  }
  const catalog = swift.slice(swift.indexOf("static let lessonCatalog"));
  const ordered = [...catalog.matchAll(/\(\.(\w+), "/g)].map((m) => rawValues.get(m[1]!));
  assertEquals(ordered, LESSON_ICONS.map((icon) => icon.id));
});

Deno.test("une icône inconnue devient le livre, une icône accentuée est reconnue", () => {
  assertEquals(normalizeIcon("licorne"), DEFAULT_ICON);
  assertEquals(normalizeIcon(42), DEFAULT_ICON);
  assertEquals(normalizeIcon(" Globe "), "globe");
  assertEquals(normalizeIcon("trophée"), "trophee");
  assertEquals(normalizeIcon("livre ouvert"), "livre-ouvert");
});
