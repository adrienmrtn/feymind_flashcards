import { createClient } from "@/lib/supabase/server";

/**
 * Où reprendre une fois la session ouverte.
 *
 * Le compte est derrière soi : on n'y renvoie pas. Si le parcours est déjà
 * écrit en base, on ouvre l'app. Sinon le pays, premier écran qui pose une
 * question.
 */
export type ResumePath = "/commencer/compte" | "/commencer/pays" | "/app";

export async function resumePath(): Promise<ResumePath> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return "/commencer/compte";

  const { data } = await supabase
    .from("profiles")
    .select("onboarding_completed_at")
    .eq("id", user.id)
    .maybeSingle();

  if (data?.onboarding_completed_at) return "/app";
  return "/commencer/pays";
}
