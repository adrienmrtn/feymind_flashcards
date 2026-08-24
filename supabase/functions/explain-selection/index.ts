import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  callModel,
  CORS_HEADERS,
  deepStripEmDashes,
  errorResponse,
  extractJSON,
  FalError,
  jsonResponse,
} from "../_shared/fal.ts";

interface RequestBody {
  /** Le passage sélectionné dans la fiche. */
  selection?: string;
  title?: string;
  subject?: string;
  /** La fiche à plat : c'est elle qui ancre l'explication dans LE cours de l'étudiant. */
  context?: string;
  model?: string;
}

const MAX_SELECTION = 600;
const MAX_CONTEXT = 16_000;

const SYSTEM_PROMPT =
  `Un étudiant lit sa fiche de cours dans Micabo. Il a sélectionné un passage et il te demande ce que ça veut dire. Tu réponds en français, en le tutoyant.

CE QU'IL ATTEND
- Une réponse, tout de suite. Pas de reformulation de la question, pas de "bonne question", pas de "ce passage signifie que".
- Une explication ancrée dans SON cours : le contexte ci-dessous est sa fiche. Tu t'appuies dessus, et tu ne contredis jamais son cours.
- Le niveau du cours. S'il lit un cours de terminale, tu n'expliques pas comme à un doctorant, et tu ne simplifies pas jusqu'au faux.
- Si le passage est un mot de vocabulaire, tu le définis. Si c'est une phrase, tu dis ce qu'elle affirme et pourquoi c'est vrai. Si c'est une formule, tu dis ce que désigne chaque terme.

INTERDIT
- Les tirets cadratins et demi-cadratins (— et –).
- Les listes à puces.
- Les phrases de remplissage : "il est important de noter", "en effet", "en résumé".
- Inventer ce qui n'est ni dans le passage ni dans le contexte. Si le cours ne dit pas assez pour répondre, dis-le dans "body" au lieu de combler.

MISE EN FORME
Tu peux utiliser **gras** pour un terme clé, *italique* pour une nuance, et $x^2$ pour une formule. Pas de surlignage, pas de markdown.

FORMAT DE SORTIE
Réponds uniquement par un objet JSON compact, une seule ligne, sans texte autour :

{
  "headline": "Une phrase qui répond, et qui se suffit à elle-même.",
  "body": "Deux à quatre phrases qui développent, avec le vocabulaire du cours.",
  "example": "Un exemple concret, seulement s'il éclaire vraiment. Sinon omets le champ.",
  "watchOut": "La confusion classique sur ce point, seulement si elle existe. Sinon omets le champ.",
  "card": { "front": "Une question de révision sur ce passage", "back": "La réponse, en une à deux phrases" }
}`;

interface Explanation {
  headline: string;
  body: string;
  example?: string;
  watchOut?: string;
  card?: { front: string; back: string };
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function optionalText(value: unknown): string | undefined {
  const result = text(value);
  return result.length > 0 ? result : undefined;
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const body = (await request.json()) as RequestBody;
    const selection = (body.selection ?? "").trim().slice(0, MAX_SELECTION);
    const context = (body.context ?? "").trim().slice(0, MAX_CONTEXT);

    if (selection.length < 2) {
      throw new FalError("Il n'y a pas de passage à expliquer.", 400);
    }

    const sections = [
      `Cours : ${body.title || "Sans titre"}`,
      body.subject ? `Matière : ${body.subject}` : "",
      `PASSAGE SÉLECTIONNÉ :\n${selection}`,
      context.length > 0 ? `SA FICHE DE COURS :\n${context}` : "",
      "Explique-lui ce passage.",
    ].filter(Boolean);

    const output = await callModel({
      prompt: sections.join("\n\n"),
      systemPrompt: SYSTEM_PROMPT,
      model: body.model,
      temperature: 0.35,
      maxTokens: 1_200,
    });

    const parsed = deepStripEmDashes(extractJSON<Record<string, unknown>>(output));

    const headline = text(parsed.headline);
    if (headline.length === 0) {
      throw new FalError("Le modèle n'a pas produit d'explication exploitable.", 502);
    }

    const rawCard = parsed.card && typeof parsed.card === "object"
      ? parsed.card as Record<string, unknown>
      : undefined;
    const front = text(rawCard?.front);
    const back = text(rawCard?.back);

    const explanation: Explanation = {
      headline,
      body: text(parsed.body),
      example: optionalText(parsed.example),
      watchOut: optionalText(parsed.watchOut),
      card: front.length > 0 && back.length > 0 ? { front, back } : undefined,
    };

    return jsonResponse({ explanation });
  } catch (error) {
    return errorResponse(error);
  }
});
