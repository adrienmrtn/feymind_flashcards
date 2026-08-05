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
import { COURSE_SYSTEM_PROMPT, VISION_SYSTEM_PROMPT } from "./prompt.ts";

interface RequestBody {
  text?: string;
  images?: string[];
  hintTitle?: string;
  sourceName?: string;
  model?: string;
}

const MAX_TEXT_LENGTH = 60_000;
const MAX_IMAGES = 6;

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const body = (await request.json()) as RequestBody;
    const text = (body.text ?? "").trim().slice(0, MAX_TEXT_LENGTH);
    const images = (body.images ?? []).slice(0, MAX_IMAGES);

    if (text.length < 40 && images.length === 0) {
      throw new FalError("Le document ne contient pas assez de contenu à analyser.", 400);
    }

    // Passe visuelle : le modèle décrit les schémas que l'extraction texte ne voit pas.
    let visualNotes = "";
    if (images.length > 0) {
      try {
        visualNotes = await callModel({
          prompt:
            "Voici les pages d'un document de cours. Décris précisément les éléments visuels utiles à la compréhension.",
          systemPrompt: VISION_SYSTEM_PROMPT,
          model: body.model,
          imageUrls: images,
          temperature: 0.2,
          maxTokens: 1600,
        });
      } catch (_error) {
        // Un échec de la passe visuelle ne doit pas bloquer la génération du cours.
        visualNotes = "";
      }
    }

    const sections: string[] = [];
    if (body.hintTitle) sections.push(`Titre souhaité par l'étudiant : ${body.hintTitle}`);
    if (body.sourceName) sections.push(`Nom du fichier source : ${body.sourceName}`);
    if (text.length > 0) sections.push(`TEXTE EXTRAIT DU DOCUMENT :\n${text}`);
    if (visualNotes) sections.push(`DESCRIPTION DES VISUELS DU DOCUMENT :\n${visualNotes}`);
    sections.push("Produis maintenant le JSON du cours.");

    const output = await callModel({
      prompt: sections.join("\n\n"),
      systemPrompt: COURSE_SYSTEM_PROMPT,
      model: body.model,
      temperature: 0.4,
      maxTokens: 8_000,
    });

    const course = deepStripEmDashes(extractJSON<Record<string, unknown>>(output));

    if (!Array.isArray(course.blocks) || course.blocks.length === 0) {
      throw new FalError("Le modèle n'a pas produit de blocs de cours exploitables.", 502);
    }

    return jsonResponse({ course, usedVision: images.length > 0 && visualNotes.length > 0 });
  } catch (error) {
    return errorResponse(error);
  }
});
