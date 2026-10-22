import { NextResponse } from "next/server";

import { LESSON_SOURCES, type LessonSource } from "@micabo/core";

import { planLesson } from "@/lib/lesson/create";

/**
 * **Le plan d'une leçon**, demandé par le navigateur depuis Home. Pas une Server Action : un
 * `fetch` vers `/api` n'est pas intercepté par le routeur pendant que le modèle écrit (voir
 * `/api/import-course`), et le plan prend une dizaine de secondes.
 */
export const maxDuration = 120;

export async function POST(request: Request) {
  let body: Record<string, unknown>;
  try {
    const parsed = (await request.json()) as unknown;
    if (!parsed || typeof parsed !== "object") throw new Error("illisible");
    body = parsed as Record<string, unknown>;
  } catch {
    return NextResponse.json({ status: "error", message: "Requête illisible." }, { status: 400 });
  }
  const source = (LESSON_SOURCES as readonly string[]).includes(body.source as string) ? (body.source as LessonSource) : "text";
  const result = await planLesson({
    lessonId: typeof body.lessonId === "string" ? body.lessonId : "",
    topic: typeof body.topic === "string" ? body.topic : undefined,
    text: typeof body.text === "string" ? body.text : undefined,
    images: Array.isArray(body.images) ? body.images.filter((item): item is string => typeof item === "string") : undefined,
    source,
    sourceName: typeof body.sourceName === "string" ? body.sourceName : undefined,
    examDate: typeof body.examDate === "string" ? body.examDate : null,
    onboarding: body.onboarding === true,
  });
  return NextResponse.json(result, { status: result.status === "ok" ? 200 : result.code === "free_limit" || result.code === "import_pro" ? 402 : 200 });
}
