import "server-only";

import { weeklyFromRow, type Availability, type AvailabilityException } from "@micabo/core";

import { cachedRead, dataClient, profileTag, userTag } from "@/lib/data/cache";
import { readProfile } from "@/lib/data/profile";
import { currentAccessToken, currentUserId } from "@/lib/data/user";

/**
 * Le temps disponible, tel que le plan le lit.
 *
 * Deux lectures, une seule question : **combien de minutes ce jour-là**. La semaine type vit
 * sur le profil, qui est déjà lu et mis en cache par tous les écrans ; les exceptions ont leur
 * table, parce qu'elles sont datées et qu'on en pose autant qu'on veut.
 *
 * Sans rien de réglé, la semaine type vaut le rythme quotidien tous les jours : le plan
 * retombe alors **exactement** sur ce qu'il faisait avant cette couche. Personne n'a à
 * remplir un formulaire pour que le produit marche.
 *
 * Les exceptions sont bornées à une fenêtre : un jour off posé il y a six mois ne concerne
 * aucun plan, et les rapatrier tous ferait grossir la lecture sans rien changer à l'écran.
 */

/** Au-delà, une exception ne peut plus toucher aucun plan : l'horizon est de 120 jours. */
const EXCEPTION_WINDOW_DAYS = 200;

export interface AvailabilityExceptionRow {
  day: string;
  minutes: number;
}

export async function listAvailabilityExceptions(): Promise<AvailabilityExceptionRow[]> {
  const userId = await currentUserId();
  const token = await currentAccessToken();
  if (!userId || !token) return [];

  const from = new Date();
  from.setDate(from.getDate() - 7);
  const since = from.toISOString().slice(0, 10);

  return cachedRead(
    userId,
    `availability:${since}`,
    [userTag(userId), profileTag(userId)],
    async () => {
      const until = new Date();
      until.setDate(until.getDate() + EXCEPTION_WINDOW_DAYS);

      const { data } = await dataClient(token)
        .from("availability_exceptions")
        .select("day, minutes")
        .eq("user_id", userId)
        .gte("day", since)
        .lte("day", until.toISOString().slice(0, 10))
        .order("day", { ascending: true });

      return (data as AvailabilityExceptionRow[] | null) ?? [];
    },
  );
}

/** La disponibilité complète : semaine type et exceptions, prêtes pour le planificateur. */
export async function readAvailability(): Promise<Availability> {
  const [profile, exceptions] = await Promise.all([
    readProfile(),
    listAvailabilityExceptions(),
  ]);

  return {
    weekly: weeklyFromRow(profile?.weekly_minutes, profile?.daily_minutes ?? undefined),
    exceptions: exceptions.map(toException),
  };
}

/** Une ligne datée devient une date locale au début de la journée. */
function toException(row: AvailabilityExceptionRow): AvailabilityException {
  return { day: new Date(`${row.day}T12:00:00`), minutes: row.minutes };
}
