import { revalidateTag, unstable_cache, updateTag } from "next/cache";
import { createClient } from "@supabase/supabase-js";

import { SUPABASE_ANON_KEY, SUPABASE_URL } from "@/lib/config";

/**
 * Le cache des lectures de l'app.
 *
 * Une navigation interne est un nouveau lambda : sans cache, chaque clic refait auth +
 * Postgres. Les écritures posent un tag, donc une carte notée ou un cours importé
 * n'attendent pas l'expiration. La file de révision, elle, n'entre pas ici - ses
 * échéances bougent à chaque note.
 */

const FRESH_SECONDS = 30;

export function userTag(userId: string): string {
  return `u:${userId}`;
}

export function coursesTag(userId: string): string {
  return `u:${userId}:courses`;
}

export function courseTag(userId: string, courseId: string): string {
  return `u:${userId}:course:${courseId}`;
}

export function cardsTag(userId: string): string {
  return `u:${userId}:cards`;
}

export function examsTag(userId: string): string {
  return `u:${userId}:exams`;
}

export function entitlementTag(userId: string): string {
  return `u:${userId}:entitlement`;
}

export function profileTag(userId: string): string {
  return `u:${userId}:profile`;
}

export function socialTag(userId: string): string {
  return `u:${userId}:social`;
}

/** Client JWT, sans cookie : c'est lui que le cache a le droit d'appeler. */
export function dataClient(token: string) {
  return createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
}

export function cachedRead<T>(
  userId: string,
  key: string,
  tags: string[],
  load: () => Promise<T>,
  revalidate: number = FRESH_SECONDS,
): Promise<T> {
  return unstable_cache(load, [key, userId], { tags, revalidate })();
}

export type UserDataKind = "courses" | "cards" | "exams" | "entitlement" | "profile" | "social" | "all";

/**
 * **Expirer un tag tout de suite**, pas « à la prochaine occasion ».
 *
 * `revalidateTag(tag, "max")` est, dans Next 16, un *stale-while-revalidate* : la requête
 * suivante reçoit encore l'ancienne valeur, et la nouvelle n'est calculée qu'en arrière-plan.
 * Pour un cache de lecture c'est raisonnable ; pour l'écran qui suit une écriture, c'est un
 * cours supprimé qui réapparaît, un titre renommé qui revient à l'ancien, un import qui « n'a
 * rien donné » - et une carte notée dont l'état d'avant repart en base à la note suivante.
 *
 * `updateTag` donne la lecture de ses propres écritures, mais seulement dans une action
 * serveur : il lève ailleurs. Les routes (l'import en flux, les webhooks) passent donc par
 * `revalidateTag(tag, { expire: 0 })`, qui expire l'entrée sur-le-champ elle aussi.
 */
function expireTag(tag: string): void {
  try {
    updateTag(tag);
  } catch {
    revalidateTag(tag, { expire: 0 });
  }
}

/** Invalide le cache serveur de l'étudiant, sans toucher à la session en cours. */
export function revalidateUserData(userId: string, kind: UserDataKind = "all"): void {
  if (kind === "all") {
    expireTag(userTag(userId));
    return;
  }
  const tag =
    kind === "courses"
      ? coursesTag(userId)
      : kind === "cards"
        ? cardsTag(userId)
        : kind === "exams"
          ? examsTag(userId)
          : kind === "entitlement"
            ? entitlementTag(userId)
            : kind === "social"
              ? socialTag(userId)
              : profileTag(userId);
  expireTag(tag);
}

/**
 * **Une lecture qui échoue ne se met pas en cache.**
 *
 * `const { data } = await …` jetait l'erreur et rendait `data ?? []` : une coupure de trois
 * secondes devenait « aucune leçon », gardée trente secondes par `unstable_cache` et servie à
 * chaque écran - de quoi faire croire à un étudiant que ses cours ont disparu, ou lui faire
 * réimporter ce qu'il a déjà. Une exception levée dans la fonction mise en cache, elle, n'est
 * pas retenue : la requête suivante réessaie.
 */
export function rowsOrThrow<T>(
  result: { data: T | null; error: { message: string; code?: string } | null },
  what: string,
): T | null {
  if (result.error) {
    throw new Error(`lecture ${what} : ${result.error.code ?? ""} ${result.error.message}`.trim());
  }
  return result.data;
}
