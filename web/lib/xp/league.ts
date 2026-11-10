import type { LeagueId } from "@micabo/core";

/** L'emblème de chaque ligue, sur la pastille XP de Home et en tête de la ligue. */
export const LEAGUE_EMOJI: Record<LeagueId, string> = {
  bronze: "🥉",
  silver: "🥈",
  gold: "🥇",
  sapphire: "🔷",
  diamond: "💎",
};

/** La couleur de chaque ligue, pour le trophée : les tons de l'app, jour et nuit. */
export const LEAGUE_TONE: Record<LeagueId, "yellow" | "blue" | "lilac" | "mint" | "pink"> = {
  bronze: "pink",
  silver: "blue",
  gold: "yellow",
  sapphire: "lilac",
  diamond: "mint",
};

/** Le nom traduit d'une ligue (`app.kx.league.names.*`). */
export function leagueNameKey(league: LeagueId): string {
  return `app.kx.league.names.${league}`;
}
