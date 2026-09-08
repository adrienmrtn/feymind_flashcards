import { assertEquals } from "jsr:@std/assert@1";

import { resetCircuit } from "./circuit.ts";
import { callModel, falRetry } from "./fal.ts";

Deno.test("callModel retente Fal après un 403, sans clé Gemini", async () => {
  resetCircuit();
  const previous = falRetry.delaysMs;
  falRetry.delaysMs = [0, 0];
  Deno.env.set("FAL_KEY", "fal-test");
  Deno.env.delete("GEMINI_API_KEY");

  const originalFetch = globalThis.fetch;
  let falCalls = 0;
  globalThis.fetch = (input) => {
    const url = String(input);
    if (!url.includes("fal.run")) return Promise.reject(new Error(`unexpected ${url}`));
    falCalls += 1;
    if (falCalls === 1) return Promise.resolve(new Response("forbidden", { status: 403 }));
    return Promise.resolve(
      new Response(JSON.stringify({ output: "ok-retry" }), { status: 200 }),
    );
  };

  try {
    const output = await callModel({ prompt: "écris une fiche" });
    assertEquals(output, "ok-retry");
    assertEquals(falCalls, 2);
  } finally {
    globalThis.fetch = originalFetch;
    Deno.env.delete("FAL_KEY");
    falRetry.delaysMs = previous;
    resetCircuit();
  }
});

Deno.test("callModel bascule sur Gemini quand Fal refuse encore", async () => {
  resetCircuit();
  const previous = falRetry.delaysMs;
  falRetry.delaysMs = [0, 0];
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
    assertEquals(calls.filter((url) => url.includes("fal.run")).length, 3);
    assertEquals(calls.some((url) => url.includes("generativelanguage.googleapis.com")), true);
  } finally {
    globalThis.fetch = originalFetch;
    Deno.env.delete("FAL_KEY");
    Deno.env.delete("GEMINI_API_KEY");
    falRetry.delaysMs = previous;
    resetCircuit();
  }
});
