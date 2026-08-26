import { createClient } from "@/lib/supabase/server";

/**
 * Où reprendre une fois la session ouverte.
 *
 * Un compte déjà ouvert entre dans l'app. Relancer le parcours parce que
 * `onboarding_completed_at` est vide renvoyait les comptes iOS et les anciens
 * comptes web au premier écran — le pays — alors qu'ils venaient seulement
 * de se connecter.
 */
export type ResumePath = "/commencer/pays" | "/app";

export async function resumePath(): Promise<ResumePath> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return user ? "/app" : "/commencer/pays";
}
