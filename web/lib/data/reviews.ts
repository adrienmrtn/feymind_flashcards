import "server-only";

import {
  DEFAULT_DAILY_MINUTES,
  countNewIntroducedToday,
  newCardsPerDay,
  remainingNewCards,
  startOfDay,
} from "@micabo/core";

import { currentUser } from "@/lib/data/user";
import { createClient } from "@/lib/supabase/server";

/**
 * Le budget de cartes neuves **du jour**, partagé par toutes les sessions.
 *
 * Une révision depuis un cours et la page Réviser lisent les mêmes faits
 * (`review_logs.state_before = new` aujourd'hui). Sans ça, chaque écran se
 * servirait un plafond neuf.
 */
export async function loadNewCardBudget(): Promise<{
  minutes: number;
  rhythmNew: number;
  introducedToday: number;
  remaining: number;
}> {
  const user = await currentUser();
  const supabase = await createClient();
  const now = new Date();

  const [profile, logs] = await Promise.all([
    user
      ? supabase
          .from("profiles")
          .select("daily_minutes")
          .eq("id", user.id)
          .maybeSingle()
          .then((result) => result.data)
      : null,
    user
      ? supabase
          .from("review_logs")
          .select("state_before, reviewed_at")
          .eq("user_id", user.id)
          .eq("state_before", "new")
          .gte("reviewed_at", startOfDay(now).toISOString())
          .then((result) => result.data)
      : null,
  ]);

  const minutes = profile?.daily_minutes ?? DEFAULT_DAILY_MINUTES;
  const introducedToday = countNewIntroducedToday(
    (logs ?? []).map((row) => ({
      stateBefore: row.state_before,
      reviewedAt: new Date(row.reviewed_at),
    })),
    now,
  );

  return {
    minutes,
    rhythmNew: newCardsPerDay(minutes),
    introducedToday,
    remaining: remainingNewCards(introducedToday, minutes),
  };
}
