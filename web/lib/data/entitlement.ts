import "server-only";

import { cache } from "react";

import { entitlement } from "@micabo/core";

import { listCourses } from "@/lib/data/courses";
import { currentUser } from "@/lib/data/user";
import { createClient } from "@/lib/supabase/server";

/**
 * Le droit, lu en base.
 *
 * **Une seule lecture, un seul endroit.** Chaque écran qui ferme quelque chose passe par ici, et
 * jamais par sa propre requête : deux écrans qui décideraient chacun de leur côté finiraient par
 * ne pas être d'accord, et quelqu'un qui vient de payer verrait encore un cadenas quelque part.
 *
 * La ligne est écrite par le webhook RevenueCat avec la clé de service ; l'utilisateur la lit et
 * ne l'écrit jamais. Une politique d'écriture, même restreinte au propriétaire, laisserait
 * n'importe qui se déclarer abonné depuis une console.
 *
 * **Une échéance passée l'emporte sur le drapeau.** Le webhook devrait avoir refermé, mais un
 * événement peut se perdre, et un abonnement fini qui reste ouvert parce qu'un webhook n'est jamais
 * arrivé est une fuite qui ne se voit pas. Deux gardes valent mieux qu'un pour la seule donnée du
 * produit qui décide de qui paye.
 *
 * Mémoïsée **par requête** seulement : le droit porte une Date, et le cache inter-requêtes
 * la sérialiserait en chaîne.
 */
export const readEntitlement = cache(async (): Promise<entitlement.Entitlement> => {
  const user = await currentUser();
  if (!user) return entitlement.resolve();

  const supabase = await createClient();
  const { data } = await supabase
    .from("entitlements")
    .select("is_pro, product_id, store, period_type, expires_at, will_renew")
    .eq("user_id", user.id)
    .maybeSingle();

  if (!data) return entitlement.resolve();

  const expiresAt = data.expires_at ? new Date(data.expires_at) : null;
  const expired = expiresAt !== null && expiresAt.getTime() < Date.now();

  return entitlement.resolve({
    isPro: Boolean(data.is_pro) && !expired,
    productId: data.product_id,
    store: data.store,
    periodType: data.period_type,
    expiresAt,
    willRenew: Boolean(data.will_renew),
  });
});

/** Le premier cours est offert. Le suivant ouvre le paywall, comme sur l'iPhone. */
export const canImportNow = cache(async (): Promise<boolean> => {
  const [right, courses] = await Promise.all([readEntitlement(), listCourses()]);
  return entitlement.canImportCourse(
    right,
    courses.map((course) => ({ isFromLibrary: course.is_from_library })),
  );
});

/**
 * Combien de cours l'étudiant a écrits lui-même.
 *
 * Les cours repris de la bibliothèque n'y sont pas, exactement comme dans
 * `canImportCourse` : c'est l'import qui déclenche l'offre cadeau, et reprendre
 * la fiche de quelqu'un n'est pas un import.
 */
export const ownedCourseCount = cache(async (): Promise<number> => {
  const courses = await listCourses();
  return courses.filter((course) => !course.is_from_library).length;
});
