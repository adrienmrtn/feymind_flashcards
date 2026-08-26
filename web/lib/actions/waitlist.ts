"use server";

import { createClient } from "@/lib/supabase/server";

/**
 * L'inscription à la liste d'attente.
 *
 * C'est la seule chose que la page d'accueil sait faire aujourd'hui, et **elle la fait
 * vraiment** : il n'y a ni parcours d'accueil, ni encaissement, ni version publiée sur l'App
 * Store, et un bouton qui ne fait rien est pire que pas de bouton.
 *
 * L'insertion passe par la clé anonyme, ce qui est correct ici et nulle part ailleurs : la
 * politique de la table n'autorise que l'`insert`, jamais le `select`. Une politique de lecture
 * même restreinte exposerait la liste des adresses de tous les inscrits à n'importe quel
 * visiteur, et la forme de l'adresse est vérifiée **dans la politique** — une validation côté
 * client se contourne avec une console.
 */

export type WaitlistSource = "hero" | "pricing" | "questions" | "landing";

export interface WaitlistResult {
  status: "ok" | "already" | "invalid" | "error";
  message: string;
}

const EMAIL_SHAPE = /^[^@\s]+@[^@\s]+\.[^@\s]{2,}$/;

export async function joinWaitlist(
  email: string,
  source: WaitlistSource = "landing",
): Promise<WaitlistResult> {
  const cleaned = email.trim().toLowerCase();

  if (!EMAIL_SHAPE.test(cleaned) || cleaned.length < 6 || cleaned.length > 254) {
    return { status: "invalid", message: "Cette adresse n'a pas l'air d'en être une." };
  }

  const supabase = await createClient();
  const { error } = await supabase.from("waitlist").insert({ email: cleaned, source });

  if (!error) {
    return { status: "ok", message: "C'est noté. On te prévient dès que Micabo ouvre." };
  }

  // 23505 : violation d'unicité. Une adresse déjà inscrite n'est pas une erreur pour la
  // personne qui la retape — elle est déjà sur la liste, et c'est ce qu'elle voulait.
  if (error.code === "23505") {
    return { status: "already", message: "Tu y es déjà. On te prévient à l'ouverture." };
  }

  return {
    status: "error",
    message: "Ça n'est pas passé. Réessaie dans un instant.",
  };
}
