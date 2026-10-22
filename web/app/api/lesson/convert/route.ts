import { NextResponse } from "next/server";

import { convertLesson } from "@/lib/lesson/convert";

/**
 * **Convertir un ancien cours en leçon**, par le modèle.
 *
 * Une route et non une Server Action, pour la même raison que `/api/import-course` : un appel
 * au modèle dure de dix à trente secondes, et un `fetch` vers une adresse du layout `/app`
 * serait intercepté par le routeur. La page du chemin l'appelle à l'ouverture d'un cours sans
 * plan, puis se recharge.
 */
export const maxDuration = 120;

export async function POST(request: Request) {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ status: "error", message: "Requête illisible." }, { status: 400 });
  }
  const lessonId = (body as { lessonId?: unknown } | null)?.lessonId;
  if (typeof lessonId !== "string" || !/^[0-9a-f-]{36}$/i.test(lessonId)) {
    return NextResponse.json({ status: "error", message: "Requête illisible." }, { status: 400 });
  }
  const result = await convertLesson(lessonId);
  return NextResponse.json(result, { status: result.status === "ok" ? 200 : 502 });
}
