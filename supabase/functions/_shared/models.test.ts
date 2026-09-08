import { assertEquals } from "jsr:@std/assert@1";

import { DEFAULT_MODEL, isAllowedModel, resolveModel } from "./models.ts";

Deno.test("resolveModel", async (t) => {
  await t.step("garde un modèle autorisé", () => {
    assertEquals(resolveModel("google/gemini-2.5-flash"), "google/gemini-2.5-flash");
  });

  await t.step("réécrit Gemini 1.5, retiré chez Google", () => {
    assertEquals(resolveModel("google/gemini-flash-1.5"), DEFAULT_MODEL);
    assertEquals(resolveModel("google/gemini-flash-1.5-8b"), DEFAULT_MODEL);
  });

  await t.step("ignore un identifiant inconnu", () => {
    assertEquals(resolveModel("openai/gpt-4o"), DEFAULT_MODEL);
    assertEquals(resolveModel("anthropic/claude-3-opus"), DEFAULT_MODEL);
    assertEquals(resolveModel(""), DEFAULT_MODEL);
    assertEquals(resolveModel(undefined), DEFAULT_MODEL);
  });

  await t.step("liste les modèles autorisés", () => {
    assertEquals(isAllowedModel("google/gemini-2.5-flash-lite"), true);
    assertEquals(isAllowedModel("google/gemini-flash-1.5"), true);
    assertEquals(isAllowedModel("openai/gpt-4o"), false);
  });
});
