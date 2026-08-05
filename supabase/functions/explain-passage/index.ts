import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  callModel,
  CORS_HEADERS,
  errorResponse,
  FalError,
  jsonResponse,
  stripEmDashes,
} from "../_shared/fal.ts";

interface RequestBody {
  selection?: string;
  title?: string;
  context?: string;
  angle?: string;
  model?: string;
}

const SYSTEM_PROMPT =
  `Tu es le tuteur de Feymind. Un étudiant a surligné un passage de son cours et demande de l'aide.

RÈGLES
- Réponds en français, en trois à six phrases maximum. Pas de préambule, pas de formule de politesse.
- Reste strictement dans le contexte du cours fourni. Ne pars pas dans des généralités.
- Tu peux utiliser **gras** et ==surlignage== pour faire ressortir l'essentiel, rien d'autre.
- INTERDIT : les tirets cadratins et demi-cadratins. Pas de titres, pas de listes numérotées.
- Si le passage est ambigu, explique l'interprétation la plus probable dans ce cours.`;

const ANGLES: Record<string, string> = {
  explain: "Explique ce passage clairement, en dévoilant le raisonnement sous-jacent.",
  simpler:
    "Reformule ce passage le plus simplement possible, comme pour quelqu'un qui découvre la notion, sans perdre en exactitude.",
  example:
    "Donne un exemple concret et parlant qui illustre ce passage, puis une phrase qui relie l'exemple à la notion.",
  why: "Explique pourquoi c'est vrai et pourquoi cela compte dans ce cours.",
};

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const body = (await request.json()) as RequestBody;
    const selection = (body.selection ?? "").trim().slice(0, 4_000);

    if (selection.length === 0) {
      throw new FalError("Aucun passage sélectionné.", 400);
    }

    const instruction = ANGLES[body.angle ?? "explain"] ?? ANGLES.explain;
    const context = (body.context ?? "").trim().slice(0, 20_000);

    const prompt = [
      `Cours : ${body.title ?? "Sans titre"}`,
      `CONTEXTE DU COURS :\n${context}`,
      `PASSAGE SÉLECTIONNÉ :\n"${selection}"`,
      `DEMANDE : ${instruction}`,
    ].join("\n\n");

    const output = await callModel({
      prompt,
      systemPrompt: SYSTEM_PROMPT,
      model: body.model,
      temperature: 0.4,
      maxTokens: 900,
    });

    return jsonResponse({ answer: stripEmDashes(output.trim()) });
  } catch (error) {
    return errorResponse(error);
  }
});
