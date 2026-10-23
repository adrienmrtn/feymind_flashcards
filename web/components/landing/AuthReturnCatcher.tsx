"use client";

import { useEffect } from "react";
import type { Route } from "next";
import { useRouter } from "next/navigation";

/** Le motif posé sur `/connexion` pour dire pourquoi on y arrive. */
export const LINK_EXPIRED_REASON = "lien";

/**
 * **Un lien qui a déposé ses jetons dans le hash** (`#access_token=…`), ou son refus
 * (`#error_code=otp_expired`).
 *
 * Ce composant ramassait la session et ouvrait l'app. Il ne le pouvait plus depuis le passage au
 * flux PKCE : le client Supabase du navigateur refuse un retour implicite (« Not a valid PKCE
 * flow url »), `getSession()` rendait `null`, et l'étudiant restait sur la vitrine avec un lien
 * qui « ne marche pas », sans un mot. Ouvrir la session à la main (`setSession` avec les jetons
 * du hash) n'est pas une option : c'est précisément ce que PKCE empêche - un lien fabriqué par
 * quelqu'un d'autre connecterait la victime au compte de l'attaquant.
 *
 * Il fait donc la seule chose honnête : il efface les jetons de la barre d'adresse (ils ne
 * doivent pas finir dans l'historique ni dans un partage d'écran) et envoie sur `/connexion`, qui
 * explique et propose les trois portes.
 */
export function AuthReturnCatcher() {
  const router = useRouter();

  useEffect(() => {
    const hash = window.location.hash;
    const isTokenReturn = hash.includes("access_token") || hash.includes("refresh_token");
    const isRefusedReturn = hash.includes("error_code=") || hash.includes("error_description=");
    if (!isTokenReturn && !isRefusedReturn) return;

    window.history.replaceState(null, "", `${window.location.pathname}${window.location.search}`);
    router.replace(`/connexion?raison=${LINK_EXPIRED_REASON}` as Route);
  }, [router]);

  return null;
}
