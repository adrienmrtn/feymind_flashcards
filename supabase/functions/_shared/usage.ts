/**
 * **Ce qu'un appel au modèle a réellement coûté, et qui l'a servi.**
 *
 * Rien ne le regardait. `ai_usage` compte des appels par utilisateur et par jour, ce qui borne
 * les abus mais ne dit pas un mot de la facture : ni les jetons, ni le modèle qui a répondu.
 * Deux questions restaient donc sans réponse autrement qu'en montant une expérience à la main,
 * et les deux portent sur de l'argent.
 *
 * ## Le modèle qui répond n'est pas toujours celui qu'on demande
 *
 * Le chemin de repli demande `gemini-flash-lite-latest`, et c'est délibéré : Google ferme ses
 * versions numérotées aux clés récentes, et le 8 septembre 2026 un `gemini-2.5-flash-lite`
 * répondait 404 pendant que l'alias répondait 200. Voir `gemini.ts`, la raison y est écrite.
 *
 * Mais un alias suit les montées de version de Google, et les générations suivantes ne coûtent
 * pas le même prix : un Flash-Lite de génération 3 se facture trois à six fois le tarif d'un
 * 2.5. Le repli pourrait donc coûter plusieurs fois le chemin nominal sans que rien ne bouge
 * dans le code. **On ne règle pas ça en épinglant une version** - ce serait refaire le 404 du
 * 8 septembre - mais en lisant le nom que le fournisseur renvoie.
 *
 * ## Le cache, on ne sait pas s'il s'applique
 *
 * Gemini met en cache, tout seul, un préfixe commun d'au moins deux mille quarante-huit jetons
 * placé en tête de la requête. Le prompt système de `generate-course` en fait plus de deux
 * mille quatre cents et il est en tête : il est éligible. Seulement le trafic passe par
 * `fal-ai/any-llm`, et rien ne dit que fal répercute le cache. `cached` tranche en un appel.
 *
 * ## `null` n'est pas zéro
 *
 * Un `cached` à zéro dit « le cache n'a pas servi ». Un `cached` à `null` dit « le fournisseur
 * ne l'a pas dit ». Les confondre transformerait une absence de mesure en mesure, et c'est
 * exactement ce qu'on cherche à sortir du produit.
 */

/** Ce qu'un appel a consommé, tel que le fournisseur le rapporte. */
export interface ModelUsage {
  provider: "fal" | "gemini";
  /** L'identifiant demandé. */
  asked: string;
  /** Celui que le fournisseur dit avoir servi. Vide s'il ne le dit pas. */
  served: string;
  /** Jetons d'entrée. `null` quand le fournisseur ne les compte pas. */
  input: number | null;
  /** Jetons de sortie, les plus chers. */
  output: number | null;
  /** Jetons d'entrée servis depuis le cache. Zéro n'est pas `null` : voir l'en-tête. */
  cached: number | null;
}

/** Un entier positif, ou `null`. Un compteur absent ne se lit pas comme un compteur à zéro. */
function count(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) && value >= 0
    ? Math.round(value)
    : null;
}

/** La première clé renseignée, parmi celles que les fournisseurs emploient pour la même chose. */
function pick(source: Record<string, unknown> | null, keys: readonly string[]): number | null {
  if (!source) return null;
  for (const key of keys) {
    const found = count(source[key]);
    if (found !== null) return found;
  }
  return null;
}

function objectAt(source: unknown, key: string): Record<string, unknown> | null {
  if (!source || typeof source !== "object") return null;
  const value = (source as Record<string, unknown>)[key];
  return value && typeof value === "object" ? value as Record<string, unknown> : null;
}

/**
 * Lit le décompte d'une réponse, quelle que soit la forme qu'il y prend.
 *
 * Deux conventions circulent et on ne choisit pas laquelle arrive : celle d'OpenAI, que
 * l'endpoint compatible de Google emploie et que fal relaie, et celle de l'API Gemini native.
 * Les deux sont acceptées, et ce qui n'est dans ni l'une ni l'autre reste `null`.
 */
export function readUsage(
  payload: unknown,
  provider: ModelUsage["provider"],
  asked: string,
): ModelUsage {
  const served = payload && typeof payload === "object" &&
      typeof (payload as { model?: unknown }).model === "string"
    ? (payload as { model: string }).model
    : "";

  const openai = objectAt(payload, "usage");
  const google = objectAt(payload, "usageMetadata");

  return {
    provider,
    asked,
    served,
    input: pick(openai, ["prompt_tokens", "input_tokens"]) ??
      pick(google, ["promptTokenCount"]),
    output: pick(openai, ["completion_tokens", "output_tokens"]) ??
      pick(google, ["candidatesTokenCount"]),
    cached: pick(objectAt(openai, "prompt_tokens_details"), ["cached_tokens"]) ??
      pick(openai, ["cached_tokens"]) ??
      pick(google, ["cachedContentTokenCount"]),
  };
}

/**
 * Consigne l'appel, et le dépose dans le compteur de l'appelant s'il en tient un.
 *
 * La ligne part dans les journaux même sans compteur : une fonction qui ne s'intéresse pas à
 * sa facture ne doit pas être la seule dont on ne sache rien.
 */
export function noteUsage(usage: ModelUsage, meter?: ModelUsage[]): void {
  console.error(JSON.stringify({ usage }));
  meter?.push(usage);
}

/**
 * Le total d'une suite d'appels, et **combien d'entre eux l'ont dit**.
 *
 * Sans `reported`, un total tiré de deux appels sur cinq se lirait comme le total des cinq.
 * `served` liste les modèles réellement servis : c'est la réponse à la question des alias, et
 * elle tient en une ligne de la réponse.
 */
export function totalUsage(meter: readonly ModelUsage[]) {
  const sum = (take: (usage: ModelUsage) => number | null): number | null => {
    const known = meter.map(take).filter((value): value is number => value !== null);
    return known.length === 0 ? null : known.reduce((total, value) => total + value, 0);
  };

  return {
    calls: meter.length,
    reported: meter.filter((usage) => usage.input !== null || usage.output !== null).length,
    input: sum((usage) => usage.input),
    output: sum((usage) => usage.output),
    cached: sum((usage) => usage.cached),
    served: [...new Set(meter.map((usage) => usage.served || usage.asked))],
  };
}
