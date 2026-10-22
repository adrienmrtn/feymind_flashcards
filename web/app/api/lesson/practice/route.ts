import { NextResponse } from "next/server";

import { writePractice } from "@/lib/lesson/practice";

/** **De nouvelles questions d'entraînement** pour une leçon, demandées depuis son quiz. */
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
  const result = await writePractice(typeof body.lessonId === "string" ? body.lessonId : "");
  return NextResponse.json(result);
}
