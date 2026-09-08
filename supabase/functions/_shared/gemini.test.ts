import { assertEquals } from "jsr:@std/assert@1";

import { flattenContent, resolveGeminiModel } from "./gemini.ts";

Deno.test("resolveGeminiModel", () => {
  assertEquals(resolveGeminiModel(), "gemini-2.5-flash-lite");
  assertEquals(resolveGeminiModel("google/gemini-2.5-flash-lite"), "gemini-2.5-flash-lite");
  assertEquals(resolveGeminiModel("google/gemini-2.5-flash"), "gemini-2.5-flash");
  assertEquals(resolveGeminiModel("google/gemini-flash-1.5"), "gemini-2.5-flash-lite");
});

Deno.test("flattenContent", () => {
  assertEquals(flattenContent("bonjour"), "bonjour");
  assertEquals(flattenContent([{ text: "a" }, { text: "b" }]), "ab");
  assertEquals(flattenContent(null), "");
});
