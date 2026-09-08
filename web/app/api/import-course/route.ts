import { NextResponse } from "next/server";

import { isChoosableVisibility, isGenerationLanguage, isSheetLength } from "@micabo/core";

import { createSheetFromImport } from "@/lib/import/create-sheet";

/**
 * L'écriture de fiche **n'est pas une Server Action**, et n'est pas sous `/app`.
 *
 * Un `fetch` vers une URL du layout `/app` est intercepté par le routeur
 * Next (en-têtes RSC) : le JSON n'est pas un vol, d'où « This page couldn't
 * load » pendant que le cours s'écrit. `/api` n'a pas ce vol, et
 * l'écriture n'est plus une Server Action.
 */
export const maxDuration = 120;

export async function POST(request: Request) {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ status: "error", message: "Requête illisible." }, { status: 400 });
  }

  if (!body || typeof body !== "object") {
    return NextResponse.json({ status: "error", message: "Requête illisible." }, { status: 400 });
  }

  const row = body as Record<string, unknown>;
  if (typeof row.text !== "string") {
    return NextResponse.json({ status: "error", message: "Requête illisible." }, { status: 400 });
  }

  const source =
    row.source === "text" || row.source === "pdf" || row.source === "docx" || row.source === "youtube"
      ? row.source
      : undefined;
  const visibility = typeof row.visibility === "string" && isChoosableVisibility(row.visibility)
    ? row.visibility
    : undefined;
  const length = typeof row.length === "string" && isSheetLength(row.length) ? row.length : undefined;
  const language =
    typeof row.language === "string" && isGenerationLanguage(row.language) ? row.language : undefined;

  const result = await createSheetFromImport({
    text: row.text,
    hintTitle: typeof row.hintTitle === "string" ? row.hintTitle : undefined,
    sourceName: typeof row.sourceName === "string" ? row.sourceName : undefined,
    source,
    visibility,
    blocks: typeof row.blocks === "number" ? row.blocks : undefined,
    length,
    language,
    instructions: typeof row.instructions === "string" ? row.instructions : undefined,
    images: Array.isArray(row.images)
      ? row.images.filter((item): item is string => typeof item === "string")
      : undefined,
  });

  return NextResponse.json(result);
}
