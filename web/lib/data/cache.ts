import { revalidateTag, unstable_cache } from "next/cache";
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

/** Invalide le cache serveur de l'étudiant, sans toucher à la session en cours. */
export function revalidateUserData(userId: string, kind: UserDataKind = "all"): void {
  if (kind === "all") {
    revalidateTag(userTag(userId), "max");
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
  revalidateTag(tag, "max");
}
