import { NextResponse, type NextRequest } from "next/server";

import { createClient } from "@/lib/supabase/server";

/**
 * Une entrée par mot de passe, **pour le développement local uniquement.**
 *
 * Elle existe parce que l'app authentifiée est autrement invérifiable : Apple et Google demandent
 * un vrai compte et un vrai navigateur, et le lien par courriel demande un envoyeur qui n'est pas
 * encore branché. Sans elle, tout ce qui vit derrière la porte — les cours, la fiche, les cartes,
 * la session — ne pourrait être ni essayé ni montré.
 *
 * **Ce n'est pas un contournement**, et c'est ce qui la rend acceptable : elle appelle
 * `signInWithPassword`, donc elle exige le mot de passe. Elle n'accorde rien que GoTrue
 * n'accorderait pas à un formulaire de connexion ordinaire. Deux verrous en plus, par précaution :
 *
 * 1. elle est **inerte en production** (`NODE_ENV`), donc elle ne répond pas sur le site ;
 * 2. elle n'accepte que les adresses en `@micabo.test`, qui ne peuvent pas être de vrais comptes.
 *
 * Elle disparaîtra le jour où l'aller-retour OAuth aura été essayé une fois par un humain.
 *
 *     /auth/dev?email=essai.web@micabo.test&password=…
 */
export async function GET(request: NextRequest) {
  if (process.env.NODE_ENV === "production") {
    return new NextResponse("Introuvable.", { status: 404 });
  }

  const url = new URL(request.url);
  const email = url.searchParams.get("email") ?? "";
  const password = url.searchParams.get("password") ?? "";

  if (!email.endsWith("@micabo.test")) {
    return new NextResponse("Réservé aux comptes d'essai.", { status: 403 });
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword({ email, password });

  if (error) {
    return new NextResponse(`Connexion refusée : ${error.message}`, { status: 401 });
  }

  return NextResponse.redirect(new URL("/app", url.origin));
}
