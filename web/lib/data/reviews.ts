import "server-only";

import {
  DEFAULT_DAILY_MINUTES,
  newCardsPerDay,
  remainingNewCards,
  startOfDay,
} from "@micabo/core";

import { cachedRead, cardsTag, dataClient, profileTag, userTag } from "@/lib/data/cache";
import { readProfile } from "@/lib/data/profile";
import { currentAccessToken, currentUserId } from "@/lib/data/user";
import { createClient } from "@/lib/supabase/server";

/**
 * L'historique de révision, tel que les écrans le lisent.
 *
 * **Ces lectures étaient les dernières à ne pas être mises en cache**, et c'étaient aussi les
 * plus fréquentes : le budget du jour est lu par le tableau de bord, la liste des cours, la
 * page Réviser et le profil. Le motif tenait : une note vient de déplacer une échéance, et un
 * cache l'aurait cachée. Mais la note passe par une action serveur qui pose déjà
 * `revalidateUserData(user.id, "cards")`. Il suffisait donc de taguer ces lectures avec les
 * cartes : elles s'effacent à la seconde où une carte est notée, et ne coûtent rien entre deux.
 *
 * La file de révision elle-même (`listAllCards`) reste hors cache : elle n'est lue qu'une fois,
 * au début d'une session, et son volume ne mérite pas une entrée de cache.
 */

async function reader(): Promise<{ userId: string; token: string } | null> {
  const userId = await currentUserId();
  const token = await currentAccessToken();
  if (!userId || !token) return null;
  return { userId, token };
}

/**
 * Le budget de cartes neuves **du jour**, partagé par toutes les sessions.
 *
 * Une révision depuis un cours et la page Réviser lisent les mêmes faits
 * (`review_logs.state_before = new` aujourd'hui). Sans ça, chaque écran se
 * servirait un plafond neuf.
 *
 * **On compte, on ne rapatrie plus.** La requête ramenait chaque ligne pour n'en garder que
 * le nombre - le filtre `state_before = 'new'` et la borne du jour étant déjà dans le `where`,
 * il n'y avait rien à recompter côté serveur. `head: true` laisse le compte à Postgres et ne
 * fait plus voyager les lignes.
 */
export async function loadNewCardBudget(): Promise<{
  minutes: number;
  rhythmNew: number;
  introducedToday: number;
  remaining: number;
}> {
  const profile = await readProfile();
  const minutes = profile?.daily_minutes ?? DEFAULT_DAILY_MINUTES;
  const introducedToday = await countNewCardsToday();

  return {
    minutes,
    rhythmNew: newCardsPerDay(minutes),
    introducedToday,
    remaining: remainingNewCards(introducedToday, minutes),
  };
}

async function countNewCardsToday(): Promise<number> {
  const auth = await reader();
  if (!auth) return 0;

  const dayStart = startOfDay(new Date()).toISOString();

  return cachedRead(
    auth.userId,
    // Le jour fait partie de la clé : passé minuit, le budget d'hier n'est plus le bon, et
    // il ne faut pas attendre qu'une note vienne l'effacer.
    `new-today:${dayStart.slice(0, 10)}`,
    [userTag(auth.userId), cardsTag(auth.userId)],
    async () => {
      const { count } = await dataClient(auth.token)
        .from("review_logs")
        .select("id", { count: "exact", head: true })
        .eq("user_id", auth.userId)
        .eq("state_before", "new")
        .gte("reviewed_at", dayStart);
      return count ?? 0;
    },
  );
}

/**
 * Les dates de révision depuis un jour donné - pour la flamme du calendrier.
 */
export async function loadReviewDatesSince(from: Date): Promise<Date[]> {
  const auth = await reader();
  if (!auth) return [];

  const since = from.toISOString();
  const days = await cachedRead(
    auth.userId,
    `review-days:${since.slice(0, 10)}`,
    [userTag(auth.userId), cardsTag(auth.userId)],
    async () => {
      const { data } = await dataClient(auth.token)
        .from("review_logs")
        .select("reviewed_at")
        .eq("user_id", auth.userId)
        .gte("reviewed_at", since);
      return ((data as { reviewed_at: string }[] | null) ?? []).map((row) => row.reviewed_at);
    },
  );

  return days.map((value) => new Date(value));
}

/**
 * Les révisions d'une fenêtre, **carte par carte** — pour les barres de la carte d'examen.
 */
export async function loadReviewActivitySince(
  from: Date,
): Promise<{ cardId: string; at: Date }[]> {
  const userId = await currentUserId();
  if (!userId) return [];

  const supabase = await createClient();
  const { data } = await supabase
    .from("review_logs")
    .select("card_id, reviewed_at")
    .eq("user_id", userId)
    .gte("reviewed_at", from.toISOString())
    .not("card_id", "is", null);

  return ((data as { card_id: string | null; reviewed_at: string }[] | null) ?? [])
    .filter((row) => row.card_id)
    .map((row) => ({ cardId: row.card_id as string, at: new Date(row.reviewed_at) }));
}

/**
 * Les statistiques du profil, **calculées là où sont les lignes**.
 *
 * La page en ramenait vingt mille : `card_id, reviewed_at`, sans cache, à chaque ouverture,
 * pour en tirer trois nombres et dix titres. Sur un téléphone c'était la page la plus lente
 * de l'app, et elle l'était même quand rien n'avait changé.
 *
 * Ce qui entre dans le cache est donc le **résultat**, pas les lignes : quelques centaines
 * d'octets au lieu du mégaoctet, tagué avec les cartes comme le reste. Le regroupement, lui,
 * reste en SQL - compter des passages par carte est le travail de Postgres, pas d'un lambda.
 */
export interface ProfileStats {
  /** Un horodatage par jour révisé : de quoi calculer une série sans transporter l'historique. */
  reviewDays: string[];
  topCards: { cardId: string; passes: number }[];
}

export async function loadProfileStats(): Promise<ProfileStats> {
  const auth = await reader();
  if (!auth) return { reviewDays: [], topCards: [] };

  return cachedRead(
    auth.userId,
    "profile-stats",
    [userTag(auth.userId), cardsTag(auth.userId)],
    async () => {
      const { data } = await dataClient(auth.token)
        .from("review_logs")
        .select("card_id, reviewed_at")
        .eq("user_id", auth.userId)
        .order("reviewed_at", { ascending: false })
        .limit(20000);

      const rows = (data as { card_id: string | null; reviewed_at: string }[] | null) ?? [];

      // Un jour révisé suffit à la série : garder les vingt mille horodatages pour n'en
      // regarder que la date était le vrai coût de cette page.
      const days = new Map<string, string>();
      const passes = new Map<string, number>();
      for (const row of rows) {
        days.set(row.reviewed_at.slice(0, 10), row.reviewed_at);
        if (row.card_id) passes.set(row.card_id, (passes.get(row.card_id) ?? 0) + 1);
      }

      const topCards = [...passes.entries()]
        .map(([cardId, count]) => ({ cardId, passes: count }))
        .sort((left, right) => right.passes - left.passes)
        .slice(0, 40);

      return { reviewDays: [...days.values()], topCards };
    },
  );
}
