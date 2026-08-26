import { createClient } from "@/lib/supabase/server";

/**
 * Où reprendre une fois la session ouverte.
 *
 * Le compte n'est plus la porte : s'il n'y a personne, on ouvre la première question.
 * Si le parcours est déjà écrit en base, on ouvre l'app. Sinon le pays, premier écran
 * qui pose une question — les réponses déjà données sont encore sur l'appareil.
 */
export type ResumePath = "/commencer/pays" | "/commencer/compte" | "/app";

export async function resumePath(): Promise<ResumePath> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return "/commencer/pays";

  const { data } = await supabase
    .from("profiles")
    .select("onboarding_completed_at")
    .eq("id", user.id)
    .maybeSingle();

  if (data?.onboarding_completed_at) return "/app";
  return "/commencer/pays";
}
