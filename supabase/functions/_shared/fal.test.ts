import { assertEquals, assertRejects } from "jsr:@std/assert@1";

import { resetCircuit } from "./circuit.ts";
import { callModel, falLadder, falRetry, OTHER_FAMILY } from "./fal.ts";
import type { ModelUsage } from "./usage.ts";

/** Rejoue un tour de `callModel` avec un faux `fetch`, sans attendre les pauses. */
async function withProviders(
  options: { falKey?: string; geminiKey?: string },
  handler: (url: string, calls: string[], body: Record<string, unknown>) => Response,
  run: (calls: string[], bodies: Array<Record<string, unknown>>) => Promise<void>,
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
  const bodies: Array<Record<string, unknown>> = [];
  globalThis.fetch = (input, init) => {
    const url = String(input);
    calls.push(url);
    const body = JSON.parse(String(init?.body ?? "{}")) as Record<string, unknown>;
    bodies.push(body);
    return Promise.resolve(handler(url, calls, body));
  };

  try {
    await run(calls, bodies);
  } finally {
    globalThis.fetch = originalFetch;
    Deno.env.delete("FAL_KEY");
    Deno.env.delete("GEMINI_API_KEY");
    falRetry.delaysMs = previousDelays;
    resetCircuit();
  }
}

const isFal = (url: string) => url.includes("fal.run");
const isGemini = (url: string) => url.includes("generativelanguage.googleapis.com");
const falCalls = (calls: string[]) => calls.filter(isFal).length;
const geminiCalls = (calls: string[]) => calls.filter(isGemini).length;

function geminiOk(): Response {
  return new Response(
    JSON.stringify({ choices: [{ message: { content: "ok-gemini" } }] }),
    { status: 200 },
  );
}

function falOk(output = "ok-fal"): Response {
  return new Response(JSON.stringify({ output }), { status: 200 });
}

/** Le 400 que fal rend quand Google, derrière lui, a retiré le modèle (20 et 21 octobre 2026). */
function falModelGone(): Response {
  return new Response(
    JSON.stringify({
      detail: "Error code: 404 - {'error': {'message': 'Provider returned error', 'code': 404, 'metadata': {'raw': 'This model models/gemini-2.5-flash is no longer available'}}}",
    }),
    { status: 400 },
  );
}

// MARK: - L'ordre des fournisseurs

/**
 * Le texte part chez Gemini d'abord. fal servait Gemini par un endpoint que fal a déprécié et
 * sur lequel Google répond 404 par intermittence ; l'API directe suit les alias `-latest`.
 */
Deno.test("le texte part chez Gemini, et fal n'est pas appelé quand Gemini répond", async () => {
  await withProviders(
    { falKey: "fal-test", geminiKey: "gemini-test" },
    (url) => (isGemini(url) ? geminiOk() : falOk()),
    async (calls) => {
      assertEquals(await callModel({ prompt: "écris une fiche" }), "ok-gemini");
      assertEquals(geminiCalls(calls), 1);
      assertEquals(falCalls(calls), 0);
    },
  );
});

Deno.test("une panne de Gemini passe à fal", async () => {
  await withProviders(
    { falKey: "fal-test", geminiKey: "gemini-test" },
    (url) =>
      isGemini(url)
        ? new Response(JSON.stringify({ error: { message: "quota" } }), { status: 429 })
        : falOk(),
    async (calls) => {
      assertEquals(await callModel({ prompt: "écris une fiche" }), "ok-fal");
      // Un 429 chez Gemini vaut l'autre alias, puis fal.
      assertEquals(geminiCalls(calls), 2);
      assertEquals(falCalls(calls), 1);
    },
  );
});

/** Deux minutes déjà attendues : fal en mettrait autant, et le client a raccroché. */
Deno.test("un dépassement de délai chez Gemini ne relance pas fal", async () => {
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
    assertEquals(geminiCalls(calls), 1);
    assertEquals(falCalls(calls), 0);
  } finally {
    globalThis.fetch = originalFetch;
    Deno.env.delete("FAL_KEY");
    Deno.env.delete("GEMINI_API_KEY");
    resetCircuit();
  }
});

/** La vision garde fal devant : c'est le chemin éprouvé des photos de cours. */
Deno.test("la vision part chez fal, et passe à Gemini sur un refus de compte", async () => {
  await withProviders(
    { falKey: "fal-test", geminiKey: "gemini-test" },
    (url) => (isFal(url) ? new Response("forbidden", { status: 403 }) : geminiOk()),
    async (calls) => {
      assertEquals(
        await callModel({ prompt: "lis cette photo", imageUrls: ["https://example.test/a.jpg"] }),
        "ok-gemini",
      );
      assertEquals(falCalls(calls), 1, "un 403 est un refus de compte : pas de second essai fal");
      assertEquals(geminiCalls(calls), 1);
    },
  );
});

Deno.test("sans clé Gemini, fal est appelé directement", async () => {
  await withProviders(
    { falKey: "fal-test" },
    () => falOk(),
    async (calls) => {
      assertEquals(await callModel({ prompt: "écris une fiche" }), "ok-fal");
      assertEquals(falCalls(calls), 1);
      assertEquals(geminiCalls(calls), 0);
    },
  );
});

Deno.test("sans clé fal, Gemini est appelé directement, vision comprise", async () => {
  await withProviders(
    { geminiKey: "gemini-test" },
    () => geminiOk(),
    async (calls) => {
      assertEquals(await callModel({ prompt: "lis", imageUrls: ["https://example.test/a.jpg"] }), "ok-gemini");
      assertEquals(falCalls(calls), 0);
      assertEquals(geminiCalls(calls), 1);
    },
  );
});

// MARK: - L'échelle fal

/**
 * `[demandé, Flash, demandé]` rejouait trois fois le même modèle quand Flash était demandé.
 * L'échelle n'a plus de doublon, et finit toujours par une autre famille : c'est le seul
 * barreau qui ait une chance quand Google a retiré un modèle.
 */
Deno.test("l'échelle fal n'a pas de doublon et finit par une autre famille", () => {
  assertEquals(falLadder("google/gemini-2.5-flash-lite", false), [
    "google/gemini-2.5-flash-lite",
    "google/gemini-2.5-flash",
    OTHER_FAMILY,
  ]);
  assertEquals(falLadder("google/gemini-2.5-flash", false), ["google/gemini-2.5-flash", OTHER_FAMILY]);
  assertEquals(falLadder("google/gemini-2.5-flash", true), ["google/gemini-2.5-flash"]);
});

/** Un 500 amont est une panne passagère : là, changer de modèle a un sens. */
Deno.test("une panne de fal est retentée sur chaque barreau, puis remonte", async () => {
  await withProviders(
    { falKey: "fal-test" },
    () => new Response("boom", { status: 500 }),
    async (calls) => {
      await assertRejects(() => callModel({ prompt: "écris une fiche" }));
      assertEquals(falCalls(calls), 3);
    },
  );
});

Deno.test("le second essai de fal suffit quand le premier modèle seul refusait", async () => {
  await withProviders(
    { falKey: "fal-test" },
    (_url, calls) => (falCalls(calls) === 1 ? new Response("boom", { status: 500 }) : falOk("ok-retry")),
    async (calls) => {
      assertEquals(await callModel({ prompt: "écris une fiche" }), "ok-retry");
      assertEquals(falCalls(calls), 2);
    },
  );
});

/**
 * Le 8 septembre 2026, fal a refusé en 403 sur Flash comme sur Flash-Lite : un refus de
 * compte. Les deux essais supplémentaires ont ajouté dix secondes d'attente pour aboutir au
 * même repli. Un 403 doit donc sortir tout de suite.
 */
Deno.test("un 403 de fal ne se retente pas", async () => {
  await withProviders(
    { falKey: "fal-test" },
    () => new Response("forbidden", { status: 403 }),
    async (calls) => {
      await assertRejects(() => callModel({ prompt: "écris une fiche" }));
      assertEquals(falCalls(calls), 1);
    },
  );
});

/**
 * Le 21 octobre 2026, Google répondait « gemini-2.5-flash is no longer available » derrière
 * fal. Redemander un autre Gemini à fal rendait le même 404 après dix secondes de pause. Le
 * modèle retiré doit sauter droit au barreau d'une autre famille, sans attendre.
 */
Deno.test("un modèle retiré chez fal saute à l'autre famille sans repasser par Google", async () => {
  await withProviders(
    { falKey: "fal-test" },
    (_url, _calls, body) => (String(body.model).startsWith("google/") ? falModelGone() : falOk("ok-autre")),
    async (calls, bodies) => {
      assertEquals(await callModel({ prompt: "écris une fiche" }), "ok-autre");
      assertEquals(falCalls(calls), 2);
      assertEquals(bodies.map((body) => body.model), ["google/gemini-2.5-flash-lite", OTHER_FAMILY]);
    },
  );
});

Deno.test("un modèle retiré sur le dernier barreau remonte sans boucler", async () => {
  await withProviders(
    { falKey: "fal-test" },
    () => falModelGone(),
    async (calls) => {
      await assertRejects(() => callModel({ prompt: "écris une fiche", model: "google/gemini-2.5-flash" }));
      // Flash puis l'autre famille : deux barreaux, pas un de plus.
      assertEquals(falCalls(calls), 2);
    },
  );
});

// MARK: - Le compteur

/**
 * Le compteur suit le chemin réellement pris, et pas celui qu'on espérait.
 *
 * Ce qui compte est qu'un repli laisse une ligne par appel - une par fournisseur - de sorte
 * qu'une facture inattendue se lise au bon endroit.
 */
Deno.test("le compteur garde une ligne par appel, repli compris", async () => {
  const meter: ModelUsage[] = [];

  await withProviders(
    { falKey: "fal", geminiKey: "gemini" },
    (url) =>
      isGemini(url)
        ? new Response(JSON.stringify({ error: { message: "forbidden" } }), { status: 403 })
        : new Response(JSON.stringify({ output: "une fiche", model: "google/gemini-2.5-flash-lite" })),
    async () => {
      assertEquals(await callModel({ prompt: "écris", meter }), "une fiche");
    },
  );

  // Gemini a refusé en 403 - un refus de clé, pas d'autre alias - et n'a rien compté ; fal a
  // répondu. Une ligne, celle du chemin qui a servi.
  assertEquals(meter.length, 1);
  assertEquals(meter[0]!.provider, "fal");
  // fal n'a rien dit de son décompte : `null`, et surtout pas zéro.
  assertEquals(meter[0]!.input, null);
});

Deno.test("le compteur lit le décompte de fal quand fal en rend un", async () => {
  const meter: ModelUsage[] = [];

  await withProviders(
    { falKey: "fal" },
    () =>
      new Response(JSON.stringify({
        output: "une fiche",
        model: "google/gemini-2.5-flash-lite",
        usage: { prompt_tokens: 8_000, completion_tokens: 4_000 },
      })),
    async () => {
      assertEquals(await callModel({ prompt: "écris", meter }), "une fiche");
    },
  );

  assertEquals(meter.length, 1);
  assertEquals(meter[0]!.provider, "fal");
  assertEquals(meter[0]!.input, 8_000);
  assertEquals(meter[0]!.output, 4_000);
  // Rien sur le cache : fal ne l'a pas dit, on ne conclut pas qu'il est froid.
  assertEquals(meter[0]!.cached, null);
});

// MARK: - La réponse d'erreur

Deno.test("errorResponse laisse la raison d'un 5xx, et se tait sur un 4xx", async () => {
  const { errorResponse, FalError } = await import("./fal.ts");
  const errored: string[] = [];
  const error = console.error;
  console.error = (line: string) => errored.push(line);
  try {
    const refused = errorResponse(new FalError("Le cours est trop court.", 400));
    assertEquals(refused.status, 400);
    assertEquals(errored.length, 0);

    const failed = errorResponse(
      new FalError("Le modèle n'a produit aucune carte exploitable.", 502),
    );
    assertEquals(failed.status, 502);
    assertEquals(await failed.json(), { error: "Le modèle n'a produit aucune carte exploitable." });
  } finally {
    console.error = error;
  }
  assertEquals(errored.length, 1);
  assertEquals(JSON.parse(errored[0]), {
    reponse: 502,
    raison: "Le modèle n'a produit aucune carte exploitable.",
  });
});

/**
 * Quarante-cinq « Ce thème n'a pas pu s'écrire » le 21 octobre 2026, et pas une ligne pour
 * dire si le fournisseur avait refusé ou si le JSON était tronqué. La cause voyage avec
 * l'erreur, dans les journaux comme dans le corps rendu à l'app.
 */
Deno.test("errorResponse transporte la cause quand l'erreur en porte une", async () => {
  const { errorResponse, FalError } = await import("./fal.ts");
  const errored: string[] = [];
  const error = console.error;
  console.error = (line: string) => errored.push(line);
  try {
    const failed = errorResponse(new FalError("Ce thème n'a pas pu s'écrire. Réessaie.", 502, undefined, "invalid_json"));
    assertEquals(await failed.json(), { error: "Ce thème n'a pas pu s'écrire. Réessaie.", reason: "invalid_json" });
  } finally {
    console.error = error;
  }
  assertEquals(JSON.parse(errored[0]), {
    reponse: 502,
    raison: "Ce thème n'a pas pu s'écrire. Réessaie.",
    cause: "invalid_json",
  });
});
