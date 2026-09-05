"use server";

import { cookies } from "next/headers";

import { UI_LOCALE_COOKIE, isUiLocale, type UiLocale } from "@/lib/i18n/locales";

export async function setUiLocale(locale: UiLocale): Promise<{ status: "ok" | "error" }> {
  if (!isUiLocale(locale)) return { status: "error" };
  const store = await cookies();
  store.set(UI_LOCALE_COOKIE, locale, {
    path: "/",
    maxAge: 60 * 60 * 24 * 365,
    sameSite: "lax",
  });
  // Pas de revalidatePath ici : dans l'action, cookies().get() voit encore
  // la requête d'origine, et le layout se repeindrait dans l'ancienne langue.
  return { status: "ok" };
}
