import { assertEquals, assertRejects, assertStringIncludes } from "jsr:@std/assert@1";

import { callGemini, flattenContent, resolveGeminiModel, upstreamReason } from "./gemini.ts";

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

/** Rejoue `callGemini` avec un faux `fetch`, et rend les modèles demandés dans l'ordre. */
async function withGemini(
  reply: (model: string, attempt: number) => Response,
  run: (models: string[]) => Promise<void>,
): Promise<void> {
  const originalFetch = globalThis.fetch;
  const models: string[] = [];

  globalThis.fetch = (_input, init) => {
    const body = JSON.parse(String(init?.body ?? "{}")) as { model?: string };
    models.push(body.model ?? "");
    return Promise.resolve(reply(body.model ?? "", models.length));
  };

  try {
    await run(models);
  } finally {
    globalThis.fetch = originalFetch;
  }
}

/**
 * Gemini est le dernier chemin : quand il tombe, la génération finit en 502. Le 8 septembre
 * 2026, au moins une l'a fait après avoir épuisé fal **et** Gemini. Un 503 « high demand »
 * est une file d'attente, pas un verdict : l'autre alias doit être essayé.
 */
Deno.test("callGemini essaie l'autre alias sur une panne du modèle", async () => {
  await withGemini(
    (_model, attempt) =>
      attempt === 1
        ? new Response(JSON.stringify({ error: { message: "high demand" } }), { status: 503 })
        : new Response(JSON.stringify({ choices: [{ message: { content: "ok" } }] })),
    async (models) => {
      assertEquals(await callGemini({ prompt: "écris" }, "clé"), "ok");
      assertEquals(models, ["gemini-flash-lite-latest", "gemini-flash-latest"]);
    },
  );
});

/** Un 400 parle de la requête, un 403 de la clé : les rejouer coûte un appel pour rien. */
Deno.test("callGemini n'insiste pas quand le refus vient de nous", async () => {
  for (const status of [400, 401, 403]) {
    await withGemini(
      () => new Response(JSON.stringify({ error: { message: "non" } }), { status }),
      async (models) => {
        await assertRejects(() => callGemini({ prompt: "écris" }, "clé"));
        assertEquals(models.length, 1, `statut ${status}`);
      },
    );
  }
});
