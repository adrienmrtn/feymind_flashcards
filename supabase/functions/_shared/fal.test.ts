import { assertEquals } from "jsr:@std/assert@1";

import { resetCircuit } from "./circuit.ts";
import { callModel } from "./fal.ts";

Deno.test("callModel bascule sur Gemini quand Fal refuse", async () => {
  resetCircuit();
  Deno.env.set("FAL_KEY", "fal-test");
  Deno.env.set("GEMINI_API_KEY", "gemini-test");

  const originalFetch = globalThis.fetch;
  const calls: string[] = [];
  globalThis.fetch = (input) => {
    const url = String(input);
    calls.push(url);
    if (url.includes("fal.run")) {
      return Promise.resolve(new Response("forbidden", { status: 403 }));
    }
    if (url.includes("generativelanguage.googleapis.com")) {
      return Promise.resolve(
        new Response(
          JSON.stringify({ choices: [{ message: { content: "ok-gemini" } }] }),
          { status: 200 },
        ),
      );
    }
    return Promise.reject(new Error(`unexpected ${url}`));
  };

  try {
    const output = await callModel({ prompt: "écris une fiche" });
    assertEquals(output, "ok-gemini");
    assertEquals(calls.some((url) => url.includes("fal.run")), true);
    assertEquals(calls.some((url) => url.includes("generativelanguage.googleapis.com")), true);
  } finally {
    globalThis.fetch = originalFetch;
    Deno.env.delete("FAL_KEY");
    Deno.env.delete("GEMINI_API_KEY");
    resetCircuit();
  }
});
