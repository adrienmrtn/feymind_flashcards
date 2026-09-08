import { assertEquals } from "jsr:@std/assert@1";

import { flattenReplicateOutput, resolveReplicateModel } from "./replicate.ts";

Deno.test("resolveReplicateModel", () => {
  assertEquals(resolveReplicateModel(), { owner: "google", name: "gemini-2.5-flash" });
  assertEquals(resolveReplicateModel("google/gemini-2.5-flash-lite"), {
    owner: "google",
    name: "gemini-2.5-flash",
  });
  assertEquals(resolveReplicateModel("google/gemini-flash-1.5"), {
    owner: "google",
    name: "gemini-2.5-flash",
  });
  assertEquals(resolveReplicateModel("openai/gpt-4o-mini"), {
    owner: "google",
    name: "gemini-2.5-flash",
  });
});

Deno.test("flattenReplicateOutput", () => {
  assertEquals(flattenReplicateOutput("bonjour"), "bonjour");
  assertEquals(flattenReplicateOutput(["a", "b", "c"]), "abc");
  assertEquals(flattenReplicateOutput({ text: "fiche" }), "fiche");
  assertEquals(flattenReplicateOutput(null), "");
});
