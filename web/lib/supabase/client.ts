"use client";

import { createBrowserClient } from "@supabase/ssr";

import { SUPABASE_ANON_KEY, SUPABASE_URL } from "@/lib/config";

/**
 * Le client Supabase du navigateur.
 *
 * On passe par `@supabase/ssr`, et non par la réécriture de GoTrue à la main qu'a faite
 * l'iPhone. Le choix de l'app était bon là-bas : quatre appels HTTP contre un gestionnaire de
 * paquets et une surface de mise à jour. Sur le web, ce qu'il faudrait réécrire n'est pas
 * quatre appels, c'est la mécanique de cookies, de rafraîchissement et de middleware  - 
 * exactement ce pour quoi la bibliothèque existe.
 *
 * La session vit donc dans un cookie posé par une route serveur, jamais dans `localStorage` :
 * un jeton de rafraîchissement lisible en JavaScript est un compte accessible sans mot de
 * passe. C'est la même exigence que le trousseau côté iOS, avec les moyens du web.
 */
export function createClient() {
  return createBrowserClient(SUPABASE_URL, SUPABASE_ANON_KEY);
}
