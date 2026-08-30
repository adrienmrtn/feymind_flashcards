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
 * **L'adresse unique du site, celle que Google doit retenir.**
 *
 * Elle est écrite en clair et ne suit pas `VERCEL_PROJECT_PRODUCTION_URL` : cette variable
 * rend le domaine le plus court, donc `micabo.app`, qui redirige (307) vers `www`. Une
 * balise canonique qui pointe vers une redirection fait dépenser à Google un aller-retour
 * par page, et deux hôtes qui servent le même texte se font concurrence sur la même requête.
 *
 * C'est aussi pour ça que ce n'est plus `micabo.vercel.app` : ce domaine ne répond plus.
 */
export const CANONICAL_URL = process.env.NEXT_PUBLIC_SITE_URL
  ? stripTrailingSlash(process.env.NEXT_PUBLIC_SITE_URL)
  : "https://www.micabo.app";

/**
 * Le site, celui qui bouge à chaque fusion.
 *
 * Une adresse d'aperçu (`micabo-git-<branche>-…`) reste servie longtemps après
 * la fusion de sa branche, et elle est figée : c'est vers celle-ci qu'on
 * renvoie quand on s'y est perdu.
 */
export const PRODUCTION_URL = process.env.VERCEL_PROJECT_PRODUCTION_URL
  ? `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}`
  : CANONICAL_URL;

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
 * Le site s'indexe, **et seulement en production**.
 *
 * Il a été fermé tant qu'il n'y avait rien à trouver. Il y a maintenant une vitrine, deux
 * pages de cadre et une adresse propre, donc la porte s'ouvre. Une prévisualisation reste
 * fermée sans condition : son URL meurt au déploiement suivant, et indexée elle se présente
 * dans les résultats à la place du site.
 *
 * Ce qui reste hors index, quelle que soit la valeur ici : l'app connectée, le parcours et
 * les retours d'authentification. Ce sont des écrans qui n'ont pas de sens sans session, et
 * un résultat de recherche qui mène à une redirection vers la connexion est un mauvais
 * résultat. C'est `next.config.ts` qui les ferme, par en-tête `X-Robots-Tag`, parce qu'une
 * charpente marquée « use client » ne peut pas exporter de `metadata`.
 */
export const IS_INDEXABLE = isProduction;
