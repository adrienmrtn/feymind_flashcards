import "server-only";

import { cachedRead, dataClient, profileTag, userTag } from "@/lib/data/cache";
import { currentAccessToken, currentUserId } from "@/lib/data/user";

/**
 * Le profil, **lu une fois pour tout le monde**.
 *
 * Six écrans le lisaient chacun de leur côté, chacun avec ses colonnes : la charpente prenait
 * le nom, le tableau de bord le nom et le pays, le profil y ajoutait le niveau, l'import la
 * longueur de fiche, le budget les minutes. Six requêtes non mises en cache pour une ligne
 * qui ne change qu'aux réglages, et sur téléphone chaque écran les repayait.
 *
 * Une seule lecture, toutes les colonnes, taguée `profile` : les réglages l'invalident, et
 * entre-temps une navigation ne touche plus la base pour savoir comment on s'appelle. La
 * ligne est petite - dix colonnes - donc la lire entière ne coûte rien de plus que d'en
 * lire deux.
 */
export interface ProfileRow {
  display_name: string | null;
  username: string | null;
  country_code: string | null;
  study_level: string | null;
  subjects: string[] | null;
  institution_name: string | null;
  institution_id: string | null;
  daily_minutes: number | null;
  sheet_length: string | null;
  sheet_language: string | null;
}

const PROFILE_COLUMNS =
  "display_name, username, country_code, study_level, subjects, institution_name, institution_id, daily_minutes, sheet_length, sheet_language";

export async function readProfile(): Promise<ProfileRow | null> {
  const userId = await currentUserId();
  const token = await currentAccessToken();
  if (!userId || !token) return null;

  return cachedRead(userId, "profile", [userTag(userId), profileTag(userId)], async () => {
    const { data } = await dataClient(token)
      .from("profiles")
      .select(PROFILE_COLUMNS)
      .eq("id", userId)
      .maybeSingle();
    return (data as ProfileRow | null) ?? null;
  });
}
