import { assertEquals } from "jsr:@std/assert@1";

import { callModel } from "./fal.ts";
import { resetCircuit } from "./circuit.ts";

Deno.test("callModel bascule sur Replicate quand Fal refuse", async () => {
  resetCircuit();
  Deno.env.set("FAL_KEY", "fal-test");
  Deno.env.set("REPLICATE_API_TOKEN", "r8_test");

  const originalFetch = globalThis.fetch;
  const calls: string[] = [];
  globalThis.fetch = (input, init) => {
    const url = String(input);
    calls.push(url);
    if (url.includes("fal.run")) {
      return Promise.resolve(new Response("nope", { status: 404 }));
    }
    if (url.includes("api.replicate.com") && init?.method === "POST") {
      return Promise.resolve(
        new Response(JSON.stringify({ status: "succeeded", output: ["ok-replicate"] }), {
          status: 200,
        }),
      );
    }
    return Promise.reject(new Error(`unexpected ${url}`));
  };

  try {
    const output = await callModel({ prompt: "écris une fiche" });
    assertEquals(output, "ok-replicate");
    assertEquals(calls.some((url) => url.includes("fal.run")), true);
    assertEquals(calls.some((url) => url.includes("api.replicate.com")), true);
  } finally {
    globalThis.fetch = originalFetch;
    Deno.env.delete("FAL_KEY");
    Deno.env.delete("REPLICATE_API_TOKEN");
    resetCircuit();
  }
});
