import { NextResponse } from "next/server";

import { writeExamPaper } from "@/lib/lesson/exam";

/** **Une copie d'examen blanc s'écrit** : le navigateur la demande, puis la joue. */
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
  const result = await writeExamPaper({
    title: typeof body.title === "string" ? body.title.trim().slice(0, 120) : "",
    examId: typeof body.examId === "string" ? body.examId : null,
    lessonIds: Array.isArray(body.lessonIds) ? body.lessonIds.filter((id): id is string => typeof id === "string") : [],
    minutes: typeof body.minutes === "number" ? body.minutes : 30,
  });
  return NextResponse.json(result);
}
