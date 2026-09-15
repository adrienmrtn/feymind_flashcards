import { assertEquals } from "jsr:@std/assert@1";

import { type ModelUsage, readUsage, totalUsage } from "./usage.ts";

/**
 * L'endpoint compatible OpenAI de Google, celui que `gemini.ts` appelle et que fal relaie.
 * Le `model` du niveau supérieur est ce qui répond à la question des alias.
 */
Deno.test("readUsage lit la convention OpenAI, cache compris", () => {
  const usage = readUsage({
    model: "gemini-2.5-flash-lite",
    usage: {
      prompt_tokens: 3_400,
      completion_tokens: 900,
      total_tokens: 4_300,
      prompt_tokens_details: { cached_tokens: 2_048 },
    },
  }, "gemini", "gemini-flash-lite-latest");

  assertEquals(usage, {
    provider: "gemini",
    asked: "gemini-flash-lite-latest",
    served: "gemini-2.5-flash-lite",
    input: 3_400,
    output: 900,
    cached: 2_048,
  });
});

Deno.test("readUsage lit aussi la convention de l'API Gemini native", () => {
  const usage = readUsage({
    usageMetadata: {
      promptTokenCount: 120,
      candidatesTokenCount: 40,
      cachedContentTokenCount: 0,
    },
  }, "fal", "google/gemini-2.5-flash-lite");

  assertEquals(usage.input, 120);
  assertEquals(usage.output, 40);
  // Zéro, et pas `null` : le fournisseur a compté, et le cache n'a pas servi.
  assertEquals(usage.cached, 0);
  // Il n'a pas dit quel modèle il a servi : on n'invente pas celui qu'on a demandé.
  assertEquals(usage.served, "");
});

/**
 * **`null` n'est pas zéro**, et c'est tout l'intérêt du module.
 *
 * fal ne documente pas de décompte sur `any-llm`. Rendre zéro laisserait croire qu'un appel
 * n'a rien coûté et qu'aucun cache n'a servi, alors qu'on n'en sait rien : ce serait remplacer
 * une absence de mesure par une fausse mesure, exactement ce qu'on cherche à sortir d'ici.
 */
Deno.test("un fournisseur muet rend null, jamais zéro", () => {
  const usage = readUsage({ output: "une fiche" }, "fal", "google/gemini-2.5-flash-lite");
  assertEquals(usage.input, null);
  assertEquals(usage.output, null);
  assertEquals(usage.cached, null);
  assertEquals(usage.served, "");
  assertEquals(usage.asked, "google/gemini-2.5-flash-lite");

  // Une réponse illisible ne fait pas tomber la lecture : elle ne rapporte simplement rien.
  for (const payload of [null, undefined, "texte", 42, []]) {
    assertEquals(readUsage(payload, "fal", "x").input, null);
  }

  // Un compteur absurde n'est pas un compteur.
  const faux = readUsage({ usage: { prompt_tokens: -3, completion_tokens: "beaucoup" } }, "fal", "x");
  assertEquals(faux.input, null);
  assertEquals(faux.output, null);
});

const USAGE = (over: Partial<ModelUsage> = {}): ModelUsage => ({
  provider: "fal",
  asked: "google/gemini-2.5-flash-lite",
  served: "gemini-2.5-flash-lite",
  input: 100,
  output: 50,
  cached: 0,
  ...over,
});

Deno.test("totalUsage additionne, et dit combien d'appels ont compté", () => {
  const total = totalUsage([
    USAGE(),
    USAGE({ input: 200, output: 80, cached: 64 }),
    // Celui-ci n'a rien rapporté : il compte dans `calls`, pas dans `reported`.
    USAGE({ input: null, output: null, cached: null }),
  ]);

  assertEquals(total.calls, 3);
  assertEquals(total.reported, 2);
  assertEquals(total.input, 300);
  assertEquals(total.output, 130);
  assertEquals(total.cached, 64);
});

Deno.test("totalUsage nomme les modèles réellement servis", () => {
  // C'est la réponse à la question des alias : si `gemini-flash-lite-latest` monte d'une
  // génération, donc de tarif, le nom change ici sans qu'une ligne du code ait bougé.
  const total = totalUsage([
    USAGE(),
    USAGE({ provider: "gemini", asked: "gemini-flash-lite-latest", served: "gemini-3.5-flash-lite" }),
    USAGE(),
  ]);
  assertEquals(total.served, ["gemini-2.5-flash-lite", "gemini-3.5-flash-lite"]);

  // Faute de nom servi, c'est le nom demandé qui est listé, jamais une case vide.
  assertEquals(totalUsage([USAGE({ served: "" })]).served, ["google/gemini-2.5-flash-lite"]);
});

Deno.test("totalUsage d'une suite vide ne prétend rien", () => {
  const total = totalUsage([]);
  assertEquals(total.calls, 0);
  assertEquals(total.reported, 0);
  assertEquals(total.input, null);
  assertEquals(total.output, null);
  assertEquals(total.served, []);
});
