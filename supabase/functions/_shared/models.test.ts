import { assertEquals } from "jsr:@std/assert@1";

import { DEFAULT_MODEL, isAllowedModel, resolveModel } from "./models.ts";

Deno.test("resolveModel", async (t) => {
  await t.step("garde un modèle autorisé", () => {
    assertEquals(resolveModel("google/gemini-flash-1.5-8b"), "google/gemini-flash-1.5-8b");
  });

  await t.step("ignore un identifiant inconnu", () => {
    assertEquals(resolveModel("openai/gpt-4o"), DEFAULT_MODEL);
    assertEquals(resolveModel("anthropic/claude-3-opus"), DEFAULT_MODEL);
    assertEquals(resolveModel(""), DEFAULT_MODEL);
    assertEquals(resolveModel(undefined), DEFAULT_MODEL);
  });

  await t.step("liste les modèles autorisés", () => {
    assertEquals(isAllowedModel("google/gemini-flash-1.5"), true);
    assertEquals(isAllowedModel("openai/gpt-4o"), false);
  });
});
