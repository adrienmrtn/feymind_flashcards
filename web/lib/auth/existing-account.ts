import type { SupabaseClient } from "@supabase/supabase-js";

/**
 * Ce que Supabase a déjà pour cette session.
 *
 * Une ligne `auth.users`, c'est le compte. On n'invente pas un second
 * « compte Micabo » par-dessus : c'est ce second compte qui renvoyait
 * une connexion Google dans l'accueil, puis réécrivait le profil.
 *
 * On s'en sert seulement pour **ne pas écraser** un profil déjà rempli
 * avec les réponses d'un parcours restées sur l'appareil.
 */
export async function shouldPreserveRemoteProfile(
  supabase: SupabaseClient,
  userId: string,
): Promise<boolean> {
  const [{ data: profile }, { count }] = await Promise.all([
    supabase.from("profiles").select("onboarding_completed_at").eq("id", userId).maybeSingle(),
    supabase
      .from("courses")
      .select("id", { count: "exact", head: true })
      .eq("user_id", userId)
      .is("deleted_at", null),
  ]);

  if (profile?.onboarding_completed_at) return true;
  return (count ?? 0) > 0;
}
