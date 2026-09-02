"use server";

import { revalidatePath } from "next/cache";

import { revalidateUserData } from "@/lib/data/cache";
import { createClient } from "@/lib/supabase/server";
import { isTourId } from "@/lib/tour/steps";

/**
 * Ce que le compte a vu de la visite guidée.
 *
 * En base, et non dans le navigateur. Le paywall et le cadeau se contentent du
 * `localStorage` parce qu'une offre revue est une seconde chance de vendre ;
 * une visite guidée revue à chaque changement d'appareil est un agacement.
 *
 * Ces trois actions sont des points d'entrée publics : l'identifiant de page
 * repasse par le catalogue avant d'atteindre la colonne, sinon n'importe quelle
 * chaîne finirait dans `tour_seen` et la visite s'éteindrait sans raison
 * lisible.
 *
 * Aucune ne renvoie d'erreur à l'écran. Si l'écriture échoue, la visite se
 * reproposera au prochain chargement : c'est une gêne, pas une panne, et un
 * message d'erreur au milieu d'une découverte serait pire que la gêne.
 */

async function currentAccount() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return { supabase, user };
}

/** Cette page s'est présentée. La croix compte autant que la fin. */
export async function markTourSeen(tourId: string): Promise<void> {
  if (!isTourId(tourId)) return;

  const { supabase, user } = await currentAccount();
  if (!user) return;

  const { data } = await supabase
    .from("profiles")
    .select("tour_seen")
    .eq("id", user.id)
    .maybeSingle();

  const seen = Array.isArray(data?.tour_seen) ? (data.tour_seen as string[]) : [];
  if (seen.includes(tourId)) return;

  // Le tableau est relu puis réécrit entier : deux pages visitées coup sur coup
  // dans deux onglets peuvent donc se perdre l'une l'autre. C'est assumé, la
  // conséquence est une bulle revue, et l'alternative demanderait un tableau
  // fusionné côté base pour un gain que personne ne remarquerait.
  await supabase
    .from("profiles")
    .upsert({ id: user.id, tour_seen: [...seen, tourId] }, { onConflict: "id" });

  await refresh(user.id);
}

/** « Passer la visite » : plus aucune page ne se présentera. */
export async function skipTour(): Promise<void> {
  const { supabase, user } = await currentAccount();
  if (!user) return;

  await supabase.from("profiles").upsert({ id: user.id, tour_skipped: true }, { onConflict: "id" });
  await refresh(user.id);
}

/** Depuis les réglages : tout se rejoue, de l'accueil à la session. */
export async function resetTour(): Promise<void> {
  const { supabase, user } = await currentAccount();
  if (!user) return;

  await supabase
    .from("profiles")
    .upsert({ id: user.id, tour_seen: [], tour_skipped: false }, { onConflict: "id" });
  await refresh(user.id);
}

async function refresh(userId: string): Promise<void> {
  revalidateUserData(userId, "profile");
  revalidatePath("/app");
}
