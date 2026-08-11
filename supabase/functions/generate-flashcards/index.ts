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
  title?: string;
  context?: string;
  count?: number;
  existing?: string[];
  model?: string;
}

interface GeneratedCard {
  front?: string;
  back?: string;
  hint?: string;
}

const SYSTEM_PROMPT =
  `Tu conçois des flashcards de révision en français pour l'application Micabo, dans l'esprit d'Anki.

RÈGLES
- Une carte teste UNE seule idée. Recto court, verso précis et autonome.
- Le recto est une vraie question ou une amorce à compléter, jamais un simple mot-clé.
- Le verso tient en une à trois phrases, ou une liste très courte séparée par des virgules.
- Couvre l'ensemble du cours, pas seulement le début. Varie définitions, mécanismes, comparaisons, applications.
- Pas de question dont la réponse est « oui » ou « non ».
- INTERDIT : les tirets cadratins et demi-cadratins. Pas de markdown, pas de numérotation.
- Ajoute un "hint" seulement quand il apporte vraiment quelque chose, sinon omets le champ.

FORMAT
Réponds uniquement par un tableau JSON, sans texte autour :
[{"front":"...","back":"...","hint":"..."}]`;

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const body = (await request.json()) as RequestBody;
    const context = (body.context ?? "").trim().slice(0, 40_000);
    const count = Math.min(Math.max(body.count ?? 12, 3), 30);

    if (context.length < 40) {
      throw new FalError("Le cours est trop court pour générer des flashcards.", 400);
    }

    const existing = (body.existing ?? []).slice(0, 60);
    const sections = [
      `Cours : ${body.title ?? "Sans titre"}`,
      `Génère exactement ${count} flashcards.`,
      existing.length > 0
        ? `Ces questions existent déjà, ne les répète pas et ne les reformule pas :\n${existing.map((item) => `- ${item}`).join("\n")}`
        : "",
      `CONTENU DU COURS :\n${context}`,
    ].filter(Boolean);

    const output = await callModel({
      prompt: sections.join("\n\n"),
      systemPrompt: SYSTEM_PROMPT,
      model: body.model,
      temperature: 0.5,
      maxTokens: 4_000,
    });

    const parsed = extractJSON<GeneratedCard[] | { cards?: GeneratedCard[] }>(output);
    const rawCards = Array.isArray(parsed) ? parsed : parsed.cards ?? [];

    const cards = deepStripEmDashes(rawCards)
      .filter((card) => typeof card?.front === "string" && typeof card?.back === "string")
      .map((card) => ({
        front: card.front!.trim(),
        back: card.back!.trim(),
        hint: card.hint?.trim() || undefined,
      }))
      .filter((card) => card.front.length > 0 && card.back.length > 0)
      .slice(0, count);

    if (cards.length === 0) {
      throw new FalError("Le modèle n'a produit aucune carte exploitable.", 502);
    }

    return jsonResponse({ cards });
  } catch (error) {
    return errorResponse(error);
  }
});
