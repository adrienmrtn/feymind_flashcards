import "server-only";

import { cookies } from "next/headers";

import { LEARNER_COOKIE, readLearnerCookie, writeLearnerCookie, type LocalLearner } from "@/lib/lesson/learner";

/**
 * **Ce que l'appareil sait de l'élève**, lu et écrit côté serveur : le jumeau des clés
 * `micabo.onboarding.stage`, `.tier`, `.currentScore`, `.targetScore` de l'iPhone.
 *
 * Un cookie lisible par le serveur, parce que c'est lui qui appelle `generate-lesson` : une
 * réponse gardée dans `localStorage` n'arriverait jamais jusqu'à l'audience. Il est rattaché
 * au compte qui l'a écrit (`u`) : un autre compte ouvert dans le même navigateur ne récupère
 * pas la moyenne du premier.
 */

const MAX_AGE = 60 * 60 * 24 * 365;

export async function readLocalLearner(userId: string | null): Promise<LocalLearner | null> {
  try {
    const store = await cookies();
    return readLearnerCookie(store.get(LEARNER_COOKIE)?.value, userId);
  } catch {
    // Hors requête (rendu statique), il n'y a pas de cookie : l'audience part du profil seul.
    return null;
  }
}

/**
 * Fusionne `patch` dans ce que le cookie tient déjà. `null` efface un champ : un palier changé
 * de pays, par exemple, ne doit pas survivre au changement.
 */
export async function updateLocalLearner(
  userId: string,
  patch: { [K in keyof LocalLearner]?: LocalLearner[K] | null },
): Promise<void> {
  const store = await cookies();
  const current = readLearnerCookie(store.get(LEARNER_COOKIE)?.value, userId) ?? {};
  const next: LocalLearner = { ...current, userId };
  for (const [key, value] of Object.entries(patch) as [keyof LocalLearner, unknown][]) {
    if (value === null || value === undefined) {
      if (value === null) delete next[key];
      continue;
    }
    (next as Record<string, unknown>)[key] = value;
  }
  store.set(LEARNER_COOKIE, writeLearnerCookie(next), {
    path: "/",
    maxAge: MAX_AGE,
    sameSite: "lax",
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
  });
}

/** Oublie tout : le compte est supprimé, ou un autre s'ouvre ici. */
export async function forgetLocalLearner(): Promise<void> {
  try {
    const store = await cookies();
    store.delete(LEARNER_COOKIE);
  } catch {
    // Voir plus haut.
  }
}
