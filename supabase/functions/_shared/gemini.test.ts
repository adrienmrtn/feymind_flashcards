import { assertEquals, assertRejects, assertStringIncludes } from "jsr:@std/assert@1";

import { callGemini, flattenContent, resolveGeminiModel, upstreamReason } from "./gemini.ts";
import type { ModelUsage } from "./usage.ts";

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

/**
 * Un 401 ou un 403 parle de la clé : le rejouer coûte un appel pour rien. Un 400 parle de la
 * requête, et la seule chose que la requête ait de neuf est la consigne de pensée : il vaut un
 * second essai sans elle, et pas un de plus.
 */
Deno.test("callGemini n'insiste pas quand le refus vient de nous", async () => {
  for (const status of [401, 403]) {
    await withGemini(
      () => new Response(JSON.stringify({ error: { message: "non" } }), { status }),
      async (models) => {
        await assertRejects(() => callGemini({ prompt: "écris" }, "clé"));
        assertEquals(models.length, 1, `statut ${status}`);
      },
    );
  }
  await withGemini(
    () => new Response(JSON.stringify({ error: { message: "non" } }), { status: 400 }),
    async (models) => {
      await assertRejects(() => callGemini({ prompt: "écris" }, "clé"));
      assertEquals(models, ["gemini-flash-lite-latest", "gemini-flash-lite-latest"], "avec puis sans la consigne, même alias");
    },
  );
});

/**
 * L'alias `-latest` est délibéré et ne sera pas épinglé : Google ferme ses versions
 * numérotées, et c'est ce qui rendait le repli inutile le 8 septembre. Mais un alias suit les
 * montées de génération, qui ne se facturent pas au même tarif. Le nom servi est donc lu et
 * consigné : c'est ce qui rend un changement de tarif visible sans changer une ligne ici.
 */
Deno.test("callGemini consigne le modèle servi et ce que l'appel a coûté", async () => {
  await withGemini(
    () =>
      new Response(JSON.stringify({
        model: "gemini-2.5-flash-lite",
        choices: [{ message: { content: "ok" } }],
        usage: {
          prompt_tokens: 3_400,
          completion_tokens: 900,
          prompt_tokens_details: { cached_tokens: 2_048 },
        },
      })),
    async () => {
      const meter: ModelUsage[] = [];
      assertEquals(await callGemini({ prompt: "écris", meter }, "clé"), "ok");
      assertEquals(meter.length, 1);
      assertEquals(meter[0]!.asked, "gemini-flash-lite-latest");
      assertEquals(meter[0]!.served, "gemini-2.5-flash-lite");
      assertEquals(meter[0]!.cached, 2_048);
    },
  );
});

/**
 * Les alias `-latest` ont atterri sur une génération qui réfléchit avant d'écrire, et dont
 * les pensées comptent dans `max_tokens` : le JSON des thèmes sortait tronqué le 21 octobre
 * 2026. Micabo ne demande que du JSON à remplir, donc la pensée est coupée ; un modèle qui
 * refuse la consigne en la nommant est rappelé une fois sans elle.
 */
Deno.test("callGemini coupe la pensée, et la rend si le modèle refuse la consigne", async () => {
  const bodies: Array<Record<string, unknown>> = [];
  const originalFetch = globalThis.fetch;
  globalThis.fetch = (_input, init) => {
    const body = JSON.parse(String(init?.body ?? "{}")) as Record<string, unknown>;
    bodies.push(body);
    if ("reasoning_effort" in body) {
      return Promise.resolve(
        new Response(
          JSON.stringify({ error: { message: "reasoning_effort is not supported for this model" } }),
          { status: 400 },
        ),
      );
    }
    return Promise.resolve(new Response(JSON.stringify({ choices: [{ message: { content: "ok" } }] })));
  };
  try {
    assertEquals(await callGemini({ prompt: "écris" }, "clé"), "ok");
  } finally {
    globalThis.fetch = originalFetch;
  }
  assertEquals(bodies.length, 2);
  assertEquals(bodies[0]!.reasoning_effort, "none");
  assertEquals("reasoning_effort" in bodies[1]!, false);
  assertEquals(bodies[1]!.model, bodies[0]!.model, "le même alias, sans la consigne");
});

Deno.test("callGemini retire la consigne de pensée sur tout 400, et n'insiste pas au-delà", async () => {
  await withGemini(
    () => new Response(JSON.stringify({ error: { message: "messages[0] is invalid" } }), { status: 400 }),
    async (models) => {
      await assertRejects(() => callGemini({ prompt: "écris" }, "clé"));
      // Une fois avec la consigne, une fois sans : le second 400 est le nôtre, on s'arrête.
      assertEquals(models.length, 2);
    },
  );
});

Deno.test("callGemini signale une réponse coupée par max_tokens", async () => {
  const warned: string[] = [];
  const warn = console.warn;
  console.warn = (line: string) => warned.push(line);
  try {
    await withGemini(
      () =>
        new Response(JSON.stringify({
          model: "gemini-3.5-flash",
          choices: [{ message: { content: "{\"notes\": " }, finish_reason: "length" }],
          usage: { prompt_tokens: 100, completion_tokens: 8_192 },
        })),
      async () => {
        assertEquals(await callGemini({ prompt: "écris", maxTokens: 8_192 }, "clé"), "{\"notes\": ");
      },
    );
  } finally {
    console.warn = warn;
  }
  const truncated = warned.map((line) => JSON.parse(line)).find((line) => line.gemini === "tronque");
  assertEquals(truncated, { gemini: "tronque", model: "gemini-3.5-flash", output: 8_192, max_tokens: 8_192 });
});
