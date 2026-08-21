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
  /** Formats autorisés : « basic », « cloze », « choice ». « basic » est toujours là. */
  kinds?: string[];
  model?: string;
}

interface GeneratedCard {
  front?: string;
  back?: string;
  hint?: string;
  kind?: string;
  choices?: string[];
  answerIndex?: number;
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

INDICE
- Le champ "hint" est facultatif : ne le mets que s'il aide vraiment à retrouver la réponse.
- Un indice porte sur le FOND : la catégorie, le mécanisme en jeu, la partie du cours d'où ça vient, un exemple voisin.
- INTERDIT : tout indice qui décrit la forme de la réponse (lettre initiale, nombre de mots, de lettres ou de syllabes). Ça n'apprend rien.

FORMATS DE CARTES
Chaque carte porte un champ "kind" :
- "basic" : question au recto, réponse au verso. C'est le format par défaut.
- "cloze" : texte à trou. Le recto est UNE phrase du cours dont le terme clé est remplacé par le caractère …, le verso est uniquement ce terme manquant. Un seul trou par carte, et la phrase doit rester compréhensible.
- "choice" : QCM. Le recto est la question, "choices" contient 3 ou 4 propositions courtes (8 mots maximum), toutes plausibles et de même longueur environ, "answerIndex" est l'index de la bonne (0 pour la première), et le verso reprend la bonne réponse en l'expliquant en une phrase.

FORMAT DE SORTIE
Réponds uniquement par un tableau JSON, sans texte autour :
[{"kind":"basic","front":"...","back":"...","hint":"..."},{"kind":"cloze","front":"La phrase avec un … à la place du terme.","back":"le terme"},{"kind":"choice","front":"...","choices":["...","...","..."],"answerIndex":1,"back":"..."}]`;

interface OutputCard {
  kind: string;
  front: string;
  back: string;
  hint?: string;
  choices?: string[];
  answerIndex?: number;
}

/** Graphie unique du trou, la même que côté application (`ClozeGap`). */
const GAP = "…";

function normalizeGap(text: string): string {
  let result = text;
  for (const candidate of ["[...]", "(...)", "[…]", "(…)", "_____", "____", "___", "__", "..."]) {
    result = result.split(candidate).join(GAP);
  }
  while (result.includes(GAP + GAP)) {
    result = result.split(GAP + GAP).join(GAP);
  }
  return result;
}

/**
 * Ramène une carte au format qu'elle tient vraiment : un QCM sans propositions
 * exploitables, ou un texte à trou sans trou, repasse en recto verso. Une carte
 * bancale n'est pas jetée pour autant : sa question et sa réponse restent bonnes.
 */
function normalizeCard(card: GeneratedCard, allowed: Set<string>): OutputCard {
  const back = card.back!.trim();
  const hint = card.hint?.trim() || undefined;
  const kind = typeof card.kind === "string" ? card.kind.trim().toLowerCase() : "basic";
  const front = kind === "cloze" ? normalizeGap(card.front!.trim()) : card.front!.trim();

  if (kind === "cloze" && allowed.has("cloze") && front.includes(GAP)) {
    return { kind, front, back, hint };
  }

  if (kind === "choice" && allowed.has("choice")) {
    const choices = [
      ...new Set(
        (Array.isArray(card.choices) ? card.choices : [])
          .filter((choice): choice is string => typeof choice === "string")
          .map((choice) => choice.trim())
          .filter((choice) => choice.length > 0),
      ),
    ];

    const declared = typeof card.answerIndex === "number" ? card.answerIndex : -1;
    const answerIndex = choices[declared] !== undefined
      ? declared
      : choices.findIndex((choice) => choice.toLowerCase() === back.toLowerCase());

    if (choices.length >= 2 && answerIndex >= 0) {
      return { kind, front, back, hint, choices, answerIndex };
    }
  }

  return { kind: "basic", front, back, hint };
}

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

    // Le recto verso ne se coupe pas : c'est le format qui marche sur n'importe quel
    // cours. Les deux autres sont des options, décochées depuis l'app.
    const allowedKinds = new Set(
      (body.kinds ?? ["basic", "cloze", "choice"]).filter((kind) =>
        kind === "basic" || kind === "cloze" || kind === "choice"
      ),
    );
    allowedKinds.add("basic");

    const sections = [
      `Cours : ${body.title ?? "Sans titre"}`,
      `Génère exactement ${count} flashcards.`,
      allowedKinds.size > 1
        ? `Formats autorisés : ${[...allowedKinds].join(", ")}. Mélange-les selon ce que le passage permet, sans forcer : environ la moitié en "basic".`
        : `Un seul format autorisé : "basic". N'utilise ni texte à trou ni QCM.`,
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
      .map((card) => normalizeCard(card, allowedKinds))
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
