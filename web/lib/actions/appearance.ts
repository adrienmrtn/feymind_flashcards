"use server";

import { cookies } from "next/headers";

import { APPEARANCE_COOKIE, isAppearance, type Appearance } from "@/lib/appearance";

export async function setAppearanceCookie(
  appearance: Appearance,
): Promise<{ status: "ok" | "error" }> {
  if (!isAppearance(appearance)) return { status: "error" };
  const store = await cookies();
  store.set(APPEARANCE_COOKIE, appearance, {
    path: "/",
    maxAge: 60 * 60 * 24 * 365,
    sameSite: "lax",
  });
  return { status: "ok" };
}
