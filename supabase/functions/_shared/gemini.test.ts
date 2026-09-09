import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";

import { flattenContent, resolveGeminiModel, upstreamReason } from "./gemini.ts";

/**
 * Google ferme ses versions numérotées aux clés récentes. Mesuré le 8 septembre 2026 sur la
 * clé du projet : `gemini-2.5-flash-lite` répond 404 « no longer available to new users »,
 * `gemini-flash-lite-latest` répond 200. Aucun identifiant rendu ici ne doit porter de numéro.
 */
Deno.test("resolveGeminiModel ne rend que des alias -latest", () => {
  assertEquals(resolveGeminiModel(), "gemini-flash-lite-latest");
  assertEquals(resolveGeminiModel("google/gemini-2.5-flash-lite"), "gemini-flash-lite-latest");
  assertEquals(resolveGeminiModel("google/gemini-2.5-flash"), "gemini-flash-latest");
  assertEquals(resolveGeminiModel("google/gemini-flash-1.5"), "gemini-flash-lite-latest");
  assertEquals(resolveGeminiModel("n'importe quoi"), "gemini-flash-lite-latest");

  for (const requested of ["", "google/gemini-2.5-flash", "google/gemini-2.0-flash-001"]) {
    assertEquals(/\d/.test(resolveGeminiModel(requested)), false);
  }
});

Deno.test("flattenContent", () => {
  assertEquals(flattenContent("bonjour"), "bonjour");
  assertEquals(flattenContent([{ text: "a" }, { text: "b" }]), "ab");
  assertEquals(flattenContent(["a", { text: "b" }, { autre: 1 }]), "ab");
  assertEquals(flattenContent(null), "");
});

Deno.test("upstreamReason garde le message du refus amont", () => {
  const google = JSON.stringify({
    error: { code: 404, message: "models/gemini-2.5-flash-lite is no longer available" },
  });
  assertStringIncludes(upstreamReason(google), "no longer available");

  // L'API compatible OpenAI de Google enveloppe son erreur dans un tableau.
  const wrapped = JSON.stringify([{ error: { message: "model not found" } }]);
  assertEquals(upstreamReason(wrapped), "model not found");

  assertEquals(upstreamReason("Forbidden\n\n"), "Forbidden");
  assertEquals(upstreamReason(""), "");
  assertEquals(upstreamReason("x".repeat(400)).length, 200);
});
