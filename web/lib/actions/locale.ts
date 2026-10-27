"use server";

import { cookies } from "next/headers";

import { isContentLanguage } from "@micabo/core";

import { UI_LOCALE_COOKIE, isUiLocale, type UiLocale } from "@/lib/i18n/locales";
import { createClient } from "@/lib/supabase/server";

export async function setUiLocale(locale: UiLocale): Promise<{ status: "ok" | "error" }> {
  if (!isUiLocale(locale)) return { status: "error" };
  const store = await cookies();
  store.set(UI_LOCALE_COOKIE, locale, {
    path: "/",
    maxAge: 60 * 60 * 24 * 365,
    sameSite: "lax",
  });
  // **La langue des leçons suit celle de l'interface** (`audienceLanguage`). Elle est aussi
  // posée sur le profil : un iPhone du même compte resté sur une ancienne version, qui relit
  // `sheet_language`, écrit alors dans la même langue. Sans compte, ou en cas d'échec, rien ne
  // bloque le changement de langue.
  if (isContentLanguage(locale)) {
    try {
      const supabase = await createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (user) await supabase.from("profiles").update({ sheet_language: locale }).eq("id", user.id);
    } catch {
      // Le cookie suffit au site ; le profil se remettra à jour au prochain changement.
    }
  }
  // Pas de revalidatePath ici : dans l'action, cookies().get() voit encore
  // la requête d'origine, et le layout se repeindrait dans l'ancienne langue.
  return { status: "ok" };
}
