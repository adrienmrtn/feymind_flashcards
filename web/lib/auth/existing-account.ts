import type { SupabaseClient } from "@supabase/supabase-js";

/**
 * Un compte Micabo, pas seulement une session GoTrue.
 *
 * Le déclencheur `handle_new_user` crée une ligne `profiles` à la première
 * connexion Apple ou Google. Sans ça, « le compte existe » voudrait dire
 * « on vient de l'inventer ». On ne compte donc que ceux qui ont déjà fini
 * le parcours, ou qui ont déjà un cours.
 */
export async function hasExistingMicaboAccount(
  supabase: SupabaseClient,
  userId: string,
): Promise<boolean> {
  const [{ data: profile }, { count }] = await Promise.all([
    supabase.from("profiles").select("onboarding_completed_at").eq("id", userId).maybeSingle(),
    supabase.from("courses").select("id", { count: "exact", head: true }).eq("user_id", userId),
  ]);

  if (profile?.onboarding_completed_at) return true;
  return (count ?? 0) > 0;
}
