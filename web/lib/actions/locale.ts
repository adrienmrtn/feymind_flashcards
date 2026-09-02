"use server";

import { cookies } from "next/headers";
import { revalidatePath } from "next/cache";

import { UI_LOCALE_COOKIE, isUiLocale, type UiLocale } from "@/lib/i18n/locales";

export async function setUiLocale(locale: UiLocale): Promise<{ status: "ok" | "error" }> {
  if (!isUiLocale(locale)) return { status: "error" };
  const store = await cookies();
  store.set(UI_LOCALE_COOKIE, locale, {
    path: "/",
    maxAge: 60 * 60 * 24 * 365,
    sameSite: "lax",
  });
  revalidatePath("/", "layout");
  return { status: "ok" };
}
