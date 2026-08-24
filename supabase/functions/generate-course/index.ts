import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  callModel,
  CORS_HEADERS,
  deepStripEmDashes,
  errorResponse,
  FalError,
  jsonResponse,
} from "../_shared/fal.ts";
import { parseModelJSON } from "../_shared/json.ts";
import { normalizeSheet, sheetToPlainText, stripInlineMarkup } from "../_shared/sheet.ts";
import { COURSE_SYSTEM_PROMPT, VISION_SYSTEM_PROMPT } from "./prompt.ts";

const OUTPUT_TOKEN_LIMIT = 8_192;

async function writeSheet(
  prompt: string,
  model: string | undefined,
  temperature: number,
): Promise<Record<string, unknown> | null> {
  try {
    const output = await callModel({
      prompt,
      systemPrompt: COURSE_SYSTEM_PROMPT,
      model,
      temperature,
      maxTokens: OUTPUT_TOKEN_LIMIT,
    });
    return deepStripEmDashes(parseModelJSON<Record<string, unknown>>(output));
  } catch {
    return null;
  }
}

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

    // Passe visuelle : le modèle décrit les schémas que l'extraction texte ne voit pas, et
    // relève leurs valeurs, sans quoi la fiche ne pourrait pas porter de graphe.
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
        // Un échec de la passe visuelle ne doit pas bloquer l'écriture de la fiche.
        visualNotes = "";
      }
    }

    const sections: string[] = [];
    if (body.hintTitle) sections.push(`Titre souhaité par l'étudiant : ${body.hintTitle}`);
    if (body.sourceName) sections.push(`Nom du fichier source : ${body.sourceName}`);
    if (text.length > 0) sections.push(`TEXTE EXTRAIT DU DOCUMENT :\n${text}`);
    if (visualNotes) sections.push(`DESCRIPTION DES VISUELS DU DOCUMENT :\n${visualNotes}`);
    sections.push(
      text.length > 12_000
        ? "Ce document est long : 14 blocs suffisent. JSON compact, une seule ligne."
        : "JSON compact, une seule ligne, sans indentation.",
    );
    sections.push("Écris maintenant le JSON de la fiche.");

    const prompt = sections.join("\n\n");
    let parsed = await writeSheet(prompt, body.model, 0.3);

    // Une fiche coupée ou illisible : on redemande plus court plutôt que d'abandonner.
    if (!parsed || normalizeSheet(parsed.sheet ?? parsed.blocks).length < 3) {
      parsed = await writeSheet(
        `${prompt}\n\nRéécris PLUS COURT : 12 blocs, JSON compact sur une seule ligne.`,
        body.model,
        0.15,
      );
    }

    if (!parsed) {
      throw new FalError("L'écriture de la fiche a échoué. Réessaie, le document n'a rien perdu.", 502);
    }

    const blocks = normalizeSheet(parsed.sheet ?? parsed.blocks);

    if (blocks.length < 3) {
      throw new FalError("Le modèle n'a pas produit de fiche exploitable.", 502);
    }

    // La version à plat est calculée ici, pas demandée au modèle : deux rédactions du même
    // contenu finiraient par se contredire, et celle-ci est déterministe.
    const contextText = sheetToPlainText(blocks);
    if (contextText.length < 40) {
      throw new FalError("Le modèle n'a pas produit de contenu exploitable.", 502);
    }

    const course = {
      title: typeof parsed.title === "string" ? parsed.title : "",
      subject: typeof parsed.subject === "string" ? parsed.subject : undefined,
      emoji: typeof parsed.emoji === "string" ? parsed.emoji : undefined,
      summary: typeof parsed.summary === "string" ? stripInlineMarkup(parsed.summary) : "",
      sheet: { blocks },
      contextText,
    };

    return jsonResponse({ course, usedVision: images.length > 0 && visualNotes.length > 0 });
  } catch (error) {
    return errorResponse(error);
  }
});
