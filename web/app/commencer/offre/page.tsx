import type { Route } from "next";
import { redirect } from "next/navigation";

import { entitlement } from "@micabo/core";

import { OnboardingOffer } from "@/components/onboarding/OnboardingOffer";
import { readEntitlement } from "@/lib/data/entitlement";
import { readProfile } from "@/lib/data/profile";
import { currentUser } from "@/lib/data/user";

export const dynamic = "force-dynamic";

/**
 * **L'offre, juste après le compte** - la dernière marche du parcours.
 *
 * Elle se posait sur le tableau de bord, une seconde après l'arrivée. Elle vient maintenant
 * au moment où l'étudiant vient de dire ce qu'il vise et de créer son compte : c'est l'ordre de
 * l'iPhone (le compte, puis l'essai et le paywall). C'est la même carte que sur le tableau de
 * bord (`PaywallCard`), avec son court accueil, sa croix et ses prix ; la refermer fait tomber
 * le cadeau, comme partout (`paywallClosed`), puis l'app s'ouvre.
 *
 * Sans session, il n'y a pas d'offre à montrer : retour au compte. Un abonné payé n'a rien à
 * acheter : il entre dans l'app, qui finit de déverser ses réponses.
 */
export default async function OnboardingOfferPage() {
  const user = await currentUser();
  if (!user) redirect("/commencer/compte" as Route);

  const [profile, right] = await Promise.all([readProfile(), readEntitlement()]);
  if (entitlement.isPaid(right)) redirect("/app" as Route);

  return <OnboardingOffer country={profile?.country_code ?? null} />;
}
