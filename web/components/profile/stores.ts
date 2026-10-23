/**
 * **Les deux boutiques de Micabo**, et laquelle montrer à qui.
 *
 * « Nous noter » menait toujours à l'App Store, avec le segment de pays d'un compte de test
 * (`/my/`) : un Android y tombait sur une app qu'il ne peut pas installer, et un iPhone français
 * sur la vitrine malaisienne. Les adresses sont sans pays — chaque boutique choisit celle du
 * lecteur —, et la plateforme se lit sur l'agent, côté serveur, pour qu'aucun lien ne clignote.
 */

/** La fiche App Store, sans segment de pays : Apple redirige vers la vitrine du lecteur. */
export const APP_STORE_LISTING = "https://apps.apple.com/app/micabo/id6806651497";

/** La fiche Google Play, par le nom du paquet Android (`com.micabo.app`). */
export const PLAY_STORE_LISTING = "https://play.google.com/store/apps/details?id=com.micabo.app";

export type StorePlatform = "ios" | "android" | "other";

/**
 * La boutique de cet appareil. Android d'abord : certains agents Android citent « like iPhone »
 * dans leurs jetons de compatibilité, aucun iPhone ne dit « Android ». L'iPad compte comme iOS
 * quand il se déclare ; celui qui se dit Macintosh voit les deux liens, ce qui est juste aussi.
 */
export function storePlatform(userAgent: string | null | undefined): StorePlatform {
  if (!userAgent) return "other";
  if (/android/i.test(userAgent)) return "android";
  if (/\b(?:iphone|ipad|ipod)\b/i.test(userAgent)) return "ios";
  return "other";
}

/** Les fiches à proposer pour noter l'app : la sienne sur un téléphone, les deux ailleurs. */
export function ratingListings(platform: StorePlatform): { store: "ios" | "android"; href: string }[] {
  if (platform === "ios") return [{ store: "ios", href: APP_STORE_LISTING }];
  if (platform === "android") return [{ store: "android", href: PLAY_STORE_LISTING }];
  return [
    { store: "ios", href: APP_STORE_LISTING },
    { store: "android", href: PLAY_STORE_LISTING },
  ];
}
