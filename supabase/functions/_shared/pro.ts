/**
 * **Le droit Pro, et la leçon offerte, lus par une fonction qui n'est pas `generate-lesson`.**
 *
 * `transcribe-audio` avait sa propre lecture de `is_pro` ; `generate-course` et
 * `youtube-transcript` n'en avaient aucune, et un compte gratuit y appelait le modèle autant
 * que son plafond du jour le permettait. Les trois lisent maintenant la même porte, en base
 * (`is_pro`, `free_lesson_used`), avec le même recours à RevenueCat quand la base dit non :
 * un achat que le webhook n'a pas encore recopié ne doit pas tomber sur le paywall.
 *
 * Sans secret de service — en local —, tout est permis : un essai reste possible. Avec, une
 * base qui ne répond pas **ferme** (503), comme le décompte (`consumeQuota`).
 */
import { CallerError } from "./caller.ts";
import { syncProFromRevenueCat } from "./revenuecat.ts";

async function ask(name: string, payload: Record<string, unknown>): Promise<unknown | undefined> {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return undefined;
  try {
    const response = await fetch(`${url}/rest/v1/rpc/${name}`, {
      method: "POST",
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(8_000),
    });
    if (!response.ok) {
      console.warn(JSON.stringify({ pro: name, status: response.status }));
      throw new CallerError("La vérification de ton accès est temporairement indisponible. Réessaie.", 503);
    }
    return await response.json();
  } catch (error) {
    if (error instanceof CallerError) throw error;
    console.warn(JSON.stringify({ pro: name, status: "network" }));
    throw new CallerError("La vérification de ton accès est temporairement indisponible. Réessaie.", 503);
  }
}

/** Vrai si le compte est Pro selon la base, ou selon RevenueCat (recopié au passage). */
export async function hasPro(userId: string): Promise<boolean> {
  const answer = await ask("is_pro", { p_user: userId });
  if (answer === undefined) return true;
  if (answer === true) return true;
  return await syncProFromRevenueCat(userId);
}

/**
 * Vrai si la leçon offerte reste à prendre : la même règle que `begin_lesson`, lue par
 * `free_lesson_used`. C'est elle qui laisse le parcours d'accueil lire une vidéo avant toute
 * offre, et seulement lui.
 */
export async function freeLessonAvailable(userId: string): Promise<boolean> {
  const answer = await ask("free_lesson_used", { p_user: userId });
  if (answer === undefined) return true;
  return answer === false;
}
