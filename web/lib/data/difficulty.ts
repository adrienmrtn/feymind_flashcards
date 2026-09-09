import "server-only";

import { type CardDifficulty, type DailyReview } from "@micabo/core";

import { cachedRead, cardsTag, dataClient, userTag } from "@/lib/data/cache";
import { currentAccessToken, currentUserId } from "@/lib/data/user";

/**
 * Ce que le journal de révision sait, **sans le rapatrier**.
 *
 * Deux questions différentes se posent sur `review_logs`, et aucune des deux ne demande les
 * lignes : « sur quelles cartes je me trompe » et « combien j'ai travaillé ». Les compter dans
 * le navigateur voudrait dire transporter des dizaines de milliers de lignes pour en tirer
 * quelques centaines d'octets - c'est exactement ce que la page profil avait déjà payé une
 * fois.
 *
 * Les deux fonctions SQL rendent donc l'agrégat. Elles sont en sécurité par l'appelant : la
 * politique de `review_logs` s'applique telle quelle, elles ne peuvent rien montrer de plus
 * que ce que l'étudiant voit déjà.
 */

/** Fenêtre de lecture : au-delà, un raté d'il y a quatre mois ne dit plus rien d'utile. */
export const DIFFICULTY_WINDOW_DAYS = 120;

interface DifficultyRow {
  card_id: string;
  reviews: number;
  again_count: number;
  hard_count: number;
  last_rating: number | null;
  last_reviewed_at: string | null;
}

/**
 * Par carte : combien de passages, combien de ratés.
 *
 * C'est la seule entrée du produit qui sait qu'une carte **résiste**. L'état de répétition
 * dit ce que l'algorithme croit, ceci dit ce qui s'est réellement passé.
 */
export async function loadCardDifficulty(): Promise<Map<string, CardDifficulty>> {
  const userId = await currentUserId();
  const token = await currentAccessToken();
  if (!userId || !token) return new Map();

  const rows = await cachedRead(
    userId,
    "card-difficulty",
    [userTag(userId), cardsTag(userId)],
    async () => {
      const { data } = await dataClient(token).rpc("card_difficulty", {
        since_days: DIFFICULTY_WINDOW_DAYS,
      });
      return (data as DifficultyRow[] | null) ?? [];
    },
  );

  const map = new Map<string, CardDifficulty>();
  for (const row of rows) {
    map.set(row.card_id, {
      cardId: row.card_id,
      reviews: Number(row.reviews ?? 0),
      againCount: Number(row.again_count ?? 0),
      hardCount: Number(row.hard_count ?? 0),
      lastRating: row.last_rating == null ? null : Number(row.last_rating),
      lastReviewedAt: row.last_reviewed_at ? new Date(row.last_reviewed_at) : null,
    });
  }
  return map;
}

interface DailyRow {
  day: string;
  passes: number;
  again_count: number;
}

/**
 * Un point par jour : ce qui a été passé, ce qui a été raté.
 *
 * La justesse est la statistique que le produit n'affichait nulle part, et c'est celle qui
 * rend les points faibles crédibles : un étudiant à 62 % comprend pourquoi les mêmes cartes
 * lui reviennent.
 */
export async function loadDailyReviews(
  sinceDays: number = DIFFICULTY_WINDOW_DAYS,
): Promise<DailyReview[]> {
  const userId = await currentUserId();
  const token = await currentAccessToken();
  if (!userId || !token) return [];

  const rows = await cachedRead(
    userId,
    `daily-reviews:${sinceDays}`,
    [userTag(userId), cardsTag(userId)],
    async () => {
      const { data } = await dataClient(token).rpc("review_daily_counts", {
        since_days: sinceDays,
      });
      return (data as DailyRow[] | null) ?? [];
    },
  );

  return rows.map((row) => ({
    day: new Date(`${row.day}T12:00:00`),
    passes: Number(row.passes ?? 0),
    againCount: Number(row.again_count ?? 0),
  }));
}
