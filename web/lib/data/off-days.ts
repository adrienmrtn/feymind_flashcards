import "server-only";

import { cachedRead, dataClient, profileTag, userTag } from "@/lib/data/cache";
import { currentAccessToken, currentUserId } from "@/lib/data/user";

/**
 * Les jours où l'étudiant a dit qu'il ne réviserait pas.
 *
 * C'est tout ce qui reste de la déclaration de temps. On demandait avant, jour par jour,
 * combien de minutes seraient consacrées à réviser ; personne ne le sait, et le plan passait
 * ensuite son temps à défendre un budget inventé contre celui qui l'avait inventé. La charge
 * de travail décide maintenant de la journée.
 *
 * Reste une chose que l'étudiant sait vraiment dire : le dimanche où il ne sera pas là. Elle
 * ne se devine pas, elle ne se mesure pas dans le journal, et un plan qui la ignore se met en
 * retard dès la première semaine. C'est donc la seule qu'on demande encore.
 *
 * La table `availability_exceptions` portait des minutes par jour ; on n'y écrit plus que des
 * zéros, ce qui veut dire « ce jour-là, rien ».
 */

interface OffDayRow {
  day: string;
}

/** Les jours off à venir, en date ISO (`2026-09-14`), triés. */
export async function listOffDays(): Promise<string[]> {
  const userId = await currentUserId();
  const token = await currentAccessToken();
  if (!userId || !token) return [];

  return cachedRead(userId, "off-days", [userTag(userId), profileTag(userId)], async () => {
    const { data } = await dataClient(token)
      .from("availability_exceptions")
      .select("day")
      .eq("user_id", userId)
      .eq("minutes", 0)
      .order("day", { ascending: true });
    return ((data as OffDayRow[] | null) ?? []).map((row) => row.day);
  });
}

/**
 * Les jours off, en décalage depuis aujourd'hui, dans une fenêtre donnée.
 *
 * C'est la forme que le noyau attend : il ne connaît pas les dates, seulement des rangs de
 * jours. Un jour passé ou au-delà de l'horizon ne dit plus rien et disparaît.
 */
export function offDayOffsets(days: readonly string[], today: Date, window: number): number[] {
  const first = new Date(today.getTime());
  first.setHours(0, 0, 0, 0);
  const offsets: number[] = [];
  for (const day of days) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(day)) continue;
    const date = new Date(`${day}T12:00:00`);
    date.setHours(0, 0, 0, 0);
    const offset = Math.round((date.getTime() - first.getTime()) / 86_400_000);
    if (offset >= 0 && offset < window) offsets.push(offset);
  }
  return offsets;
}
