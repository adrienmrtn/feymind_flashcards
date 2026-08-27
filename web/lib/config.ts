/**
 * La configuration du site.
 *
 * **Les valeurs par défaut sont écrites ici, en clair, et c'est délibéré.** C'est déjà ce que
 * fait `Micabo/Services/AppConfig.swift` pour l'app : l'URL du projet et la clé publiable sont
 * publiques par nature - la clé est un jeton de rôle `anon`, et tout ce qu'elle peut lire est
 * ce que le cloisonnement de Postgres autorise à un visiteur anonyme, c'est-à-dire rien.
 *
 * Le bénéfice est concret : un déploiement compile et tourne **sans qu'une seule variable ait
 * été collée dans un tableau de bord**. Ça compte ici, parce que l'accès Vercel dont je dispose
 * ne sait pas poser de variable d'environnement.
 *
 * `process.env` reste prioritaire, pour qu'un autre projet Supabase - une branche, un bac à
 * sable - se branche sans toucher au code.
 *
 * Ce qui n'a **jamais** sa place dans ce fichier : la clé de service, les clés Stripe, le
 * secret du webhook RevenueCat. Ceux-là sont des variables d'environnement serveur, ils
 * n'arrivent qu'à l'étape 5, et un préfixe `NEXT_PUBLIC_` sur l'un d'eux publierait un accès
 * total à la base dans le paquet JavaScript.
 */

export const SUPABASE_URL =
  process.env.NEXT_PUBLIC_SUPABASE_URL ?? "https://khuzodsrznanzhwlbjbx.supabase.co";

export const SUPABASE_ANON_KEY =
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtodXpvZHNyem5hbnpod2xiamJ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU5NDg1MzIsImV4cCI6MjEwMTUyNDUzMn0.-PBadJI6rdYgoHisEfP54CN126IiT9DNIXR4J-vNYLw";

export const isProduction = process.env.VERCEL_ENV === "production";

/**
 * Le site, celui qui bouge à chaque fusion.
 *
 * Une adresse d'aperçu (`micabo-git-<branche>-…`) reste servie longtemps après
 * la fusion de sa branche, et elle est figée : c'est vers celle-ci qu'on
 * renvoie quand on s'y est perdu.
 */
export const PRODUCTION_URL = process.env.VERCEL_PROJECT_PRODUCTION_URL
  ? `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}`
  : "https://micabo.vercel.app";

/** Où le site se croit hébergé. Sert aux liens absolus et au retour OAuth. */
export const SITE_URL = resolveSiteUrl();

function resolveSiteUrl(): string {
  if (process.env.NEXT_PUBLIC_SITE_URL) return stripTrailingSlash(process.env.NEXT_PUBLIC_SITE_URL);
  // Vercel donne l'URL de production du projet, et celle du déploiement en prévisualisation.
  if (process.env.VERCEL_PROJECT_PRODUCTION_URL && isProduction) {
    return `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}`;
  }
  if (process.env.VERCEL_URL) return `https://${process.env.VERCEL_URL}`;
  return "http://localhost:3000";
}

function stripTrailingSlash(value: string): string {
  return value.endsWith("/") ? value.slice(0, -1) : value;
}

/**
 * Le site ne s'indexe pas encore.
 *
 * Deux raisons, et la seconde est la vraie : une prévisualisation indexée se présente à la
 * place du site, et **il n'y a pour l'instant aucune page d'accueil** - seulement la référence
 * des fondations. Cette porte s'ouvre à l'étape 2, quand il y aura quelque chose à trouver.
 */
export const IS_INDEXABLE = false;
