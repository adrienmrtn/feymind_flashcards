import { NextResponse } from "next/server";

import { writeTheme } from "@/lib/lesson/create";

/** **Un thème s'écrit** : le navigateur en demande quatre à la fois (`lib/lesson/theme-writer.ts`). */
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
  const result = await writeTheme(
    typeof body.lessonId === "string" ? body.lessonId : "",
    typeof body.themeIndex === "number" ? body.themeIndex : -1,
    { retry: body.retry === true },
  );
  return NextResponse.json(result);
}
