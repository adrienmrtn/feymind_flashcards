import { assertEquals, assertRejects } from "jsr:@std/assert@1";

import { resetCircuit } from "./circuit.ts";
import { callModel, falRetry } from "./fal.ts";

/** Rejoue un tour de `callModel` avec un faux `fetch`, sans attendre les pauses. */
async function withProviders(
  options: { falKey?: string; geminiKey?: string },
  handler: (url: string, calls: string[]) => Response,
  run: (calls: string[]) => Promise<void>,
): Promise<void> {
  resetCircuit();
  const previousDelays = falRetry.delaysMs;
  falRetry.delaysMs = [0, 0];
  if (options.falKey) Deno.env.set("FAL_KEY", options.falKey);
  else Deno.env.delete("FAL_KEY");
  if (options.geminiKey) Deno.env.set("GEMINI_API_KEY", options.geminiKey);
  else Deno.env.delete("GEMINI_API_KEY");

  const originalFetch = globalThis.fetch;
  const calls: string[] = [];
  globalThis.fetch = (input) => {
    const url = String(input);
    calls.push(url);
    return Promise.resolve(handler(url, calls));
  };

  try {
    await run(calls);
  } finally {
    globalThis.fetch = originalFetch;
    Deno.env.delete("FAL_KEY");
    Deno.env.delete("GEMINI_API_KEY");
    falRetry.delaysMs = previousDelays;
    resetCircuit();
  }
}

const falCalls = (calls: string[]) => calls.filter((url) => url.includes("fal.run")).length;
const geminiCalls = (calls: string[]) =>
  calls.filter((url) => url.includes("generativelanguage.googleapis.com")).length;

function geminiOk(): Response {
  return new Response(
    JSON.stringify({ choices: [{ message: { content: "ok-gemini" } }] }),
    { status: 200 },
  );
}

/**
 * Le 8 septembre 2026, fal a refusé en 403 sur Flash comme sur Flash-Lite : un refus de
 * compte. Les deux essais supplémentaires ont ajouté dix secondes d'attente pour aboutir au
 * même repli. Un 403 doit donc passer la main tout de suite.
 */
Deno.test("un 403 de fal passe à Gemini sans retenter fal", async () => {
  await withProviders(
    { falKey: "fal-test", geminiKey: "gemini-test" },
    (url) => (url.includes("fal.run") ? new Response("forbidden", { status: 403 }) : geminiOk()),
    async (calls) => {
      assertEquals(await callModel({ prompt: "écris une fiche" }), "ok-gemini");
      assertEquals(falCalls(calls), 1);
      assertEquals(geminiCalls(calls), 1);
    },
  );
});

Deno.test("un 429 de fal passe à Gemini sans retenter fal", async () => {
  await withProviders(
    { falKey: "fal-test", geminiKey: "gemini-test" },
    (url) => (url.includes("fal.run") ? new Response("slow down", { status: 429 }) : geminiOk()),
    async (calls) => {
      assertEquals(await callModel({ prompt: "écris une fiche" }), "ok-gemini");
      assertEquals(falCalls(calls), 1);
    },
  );
});

/** Un 500 amont est une panne passagère : là, changer de modèle a un sens. */
Deno.test("une panne de fal est retentée, puis passe à Gemini", async () => {
  await withProviders(
    { falKey: "fal-test", geminiKey: "gemini-test" },
    (url) => (url.includes("fal.run") ? new Response("boom", { status: 500 }) : geminiOk()),
    async (calls) => {
      assertEquals(await callModel({ prompt: "écris une fiche" }), "ok-gemini");
      assertEquals(falCalls(calls), 3);
      assertEquals(geminiCalls(calls), 1);
    },
  );
});

Deno.test("le second essai de fal suffit quand le premier modèle seul refusait", async () => {
  await withProviders(
    { falKey: "fal-test" },
    (_url, calls) =>
      falCalls(calls) === 1
        ? new Response("boom", { status: 500 })
        : new Response(JSON.stringify({ output: "ok-retry" }), { status: 200 }),
    async (calls) => {
      assertEquals(await callModel({ prompt: "écris une fiche" }), "ok-retry");
      assertEquals(falCalls(calls), 2);
    },
  );
});

Deno.test("sans clé Gemini, un 403 de fal remonte tel quel", async () => {
  await withProviders(
    { falKey: "fal-test" },
    () => new Response("forbidden", { status: 403 }),
    async (calls) => {
      await assertRejects(() => callModel({ prompt: "écris une fiche" }));
      assertEquals(falCalls(calls), 1);
    },
  );
});

/** Deux minutes déjà attendues : Gemini en mettrait autant, et le client a raccroché. */
Deno.test("un dépassement de délai chez fal ne relance pas Gemini", async () => {
  resetCircuit();
  Deno.env.set("FAL_KEY", "fal-test");
  Deno.env.set("GEMINI_API_KEY", "gemini-test");
  const originalFetch = globalThis.fetch;
  const calls: string[] = [];
  globalThis.fetch = (input) => {
    calls.push(String(input));
    return Promise.reject(new DOMException("trop long", "TimeoutError"));
  };

  try {
    await assertRejects(() => callModel({ prompt: "écris une fiche" }));
    assertEquals(geminiCalls(calls), 0);
  } finally {
    globalThis.fetch = originalFetch;
    Deno.env.delete("FAL_KEY");
    Deno.env.delete("GEMINI_API_KEY");
    resetCircuit();
  }
});

Deno.test("sans clé fal, Gemini est appelé directement", async () => {
  await withProviders(
    { geminiKey: "gemini-test" },
    () => geminiOk(),
    async (calls) => {
      assertEquals(await callModel({ prompt: "écris une fiche" }), "ok-gemini");
      assertEquals(falCalls(calls), 0);
      assertEquals(geminiCalls(calls), 1);
    },
  );
});
