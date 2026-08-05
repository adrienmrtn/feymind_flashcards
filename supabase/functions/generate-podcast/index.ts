import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  callModel,
  CORS_HEADERS,
  deepStripEmDashes,
  errorResponse,
  extractJSON,
  FalError,
  jsonResponse,
  stripEmDashes,
} from "../_shared/fal.ts";
import { synthesizeBatch } from "../_shared/tts.ts";

interface RequestBody {
  title?: string;
  context?: string;
  hostVoiceId?: string;
  guestVoiceId?: string;
  targetMinutes?: number;
  model?: string;
}

interface ScriptTurn {
  speaker?: string;
  text?: string;
}

interface ScriptPayload {
  title?: string;
  turns?: ScriptTurn[];
}

const ALLOWED_VOICES = new Set([
  "French_CasualMan",
  "French_Male_Speech_New",
  "French_MaleNarrator",
  "French_MovieLeadFemale",
  "French_Female_News Anchor",
  "French_FemaleAnchor",
  "French_Female_Speech_New",
  "French_Female Journalist",
]);

const SYSTEM_PROMPT = `Tu écris le script d'un podcast éducatif français à DEUX voix pour Feymind.

PERSONNAGES
- host : l'animateur curieux, pose des questions, relance, reformule.
- guest : l'expert clair, explique, donne des exemples concrets.

STYLE
- Comme un vrai podcast étudiant : naturel, oral, vivant. Pas de lecture de cours.
- Phrases courtes. Vouvoiement entre les deux. Quelques réactions (« Exactement », « Ah oui », « Donc si je résume »).
- INTERDIT : tirets cadratins, markdown, didascalies, noms entre crochets, rires écrits, émojis.
- Ne dis jamais « dans cet épisode » plus d'une fois. Pas de pub, pas de générique long.

DURÉE ET COÛT
- Vise un podcast COURT : 12 à 16 répliques au total.
- Chaque réplique fait 1 à 3 phrases (40 à 220 caractères).
- Le texte parlé total doit rester sous 3200 caractères.
- Couvre l'essentiel du cours, pas tous les détails.

FORMAT
Réponds UNIQUEMENT par un JSON valide :
{
  "title": "Titre court du podcast",
  "turns": [
    {"speaker": "host", "text": "..."},
    {"speaker": "guest", "text": "..."}
  ]
}`;

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const body = (await request.json()) as RequestBody;
    const context = (body.context ?? "").trim().slice(0, 18_000);
    if (context.length < 80) {
      throw new FalError("Le cours est trop court pour en faire un podcast.", 400);
    }

    const hostVoiceId = ALLOWED_VOICES.has(body.hostVoiceId ?? "")
      ? body.hostVoiceId!
      : "French_CasualMan";
    const guestVoiceId = ALLOWED_VOICES.has(body.guestVoiceId ?? "")
      ? body.guestVoiceId!
      : "French_MovieLeadFemale";

    const targetMinutes = Math.min(Math.max(body.targetMinutes ?? 5, 3), 8);

    const prompt = [
      `Cours : ${body.title ?? "Sans titre"}`,
      `Durée cible : environ ${targetMinutes} minutes.`,
      `CONTENU DU COURS :\n${context}`,
      "Écris maintenant le script JSON du podcast.",
    ].join("\n\n");

    const rawScript = await callModel({
      prompt,
      systemPrompt: SYSTEM_PROMPT,
      model: body.model,
      temperature: 0.55,
      maxTokens: 2_500,
    });

    const script = deepStripEmDashes(extractJSON<ScriptPayload>(rawScript));
    const turns = (script.turns ?? [])
      .map((turn) => ({
        speaker: turn.speaker === "guest" ? "guest" : "host",
        text: stripEmDashes((turn.text ?? "").trim()),
      }))
      .filter((turn) => turn.text.length > 0)
      .slice(0, 18);

    if (turns.length < 4) {
      throw new FalError("Le script du podcast est trop court ou invalide.", 502);
    }

    // Garde-fou coût : on coupe si le modèle a été trop bavard.
    let totalChars = 0;
    const cappedTurns: typeof turns = [];
    for (const turn of turns) {
      if (totalChars + turn.text.length > 3_400) break;
      cappedTurns.push(turn);
      totalChars += turn.text.length;
    }

    if (cappedTurns.length < 4) {
      throw new FalError("Impossible de produire un podcast assez dense sans dépasser le budget.", 502);
    }

    const audioResults = await synthesizeBatch(
      cappedTurns.map((turn) => ({
        text: turn.text,
        voiceId: turn.speaker === "guest" ? guestVoiceId : hostVoiceId,
      })),
      3,
    );

    const segments = cappedTurns.map((turn, index) => ({
      id: crypto.randomUUID(),
      speaker: turn.speaker,
      text: turn.text,
      audioURL: audioResults[index].url,
      durationMs: audioResults[index].durationMs,
    }));

    const estimatedCostCents = Math.ceil((totalChars / 1000) * 6);

    return jsonResponse({
      podcast: {
        title: stripEmDashes(script.title?.trim() || `Podcast : ${body.title ?? "Cours"}`),
        hostVoiceId,
        guestVoiceId,
        segments,
        estimatedCostCents,
      },
    });
  } catch (error) {
    return errorResponse(error);
  }
});
