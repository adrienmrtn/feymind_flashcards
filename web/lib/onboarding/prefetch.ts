import type { useRouter } from "next/navigation";

type Router = ReturnType<typeof useRouter>;

/**
 * **Précharger un écran en entier**, et pas seulement sa charpente.
 *
 * Les pages du site sont rendues à la demande (la langue se lit dans un cookie). Pour une telle
 * page, `router.prefetch(href)` ne rapporte que ce qui précède le premier `loading.js` - ici,
 * rien du tout - et chaque « Continuer » attendait donc un aller-retour au serveur avant de
 * changer d'écran. `kind: "full"` rapporte l'écran entier, gardé `staleTimes.static` (trois
 * minutes, `next.config.ts`) : la navigation se fait ensuite sans réseau.
 *
 * Les routes typées du projet ne déclarent que l'adresse, et le type de l'option vient d'un module
 * interne de Next (`PrefetchKind`) : on passe la chaîne que Next compare.
 */
export function prefetchStep(router: Router, href: string): void {
  const prefetch = router.prefetch as unknown as (href: string, options?: { kind: "full" | "auto" }) => void;
  prefetch.call(router, href, { kind: "full" });
}
