import { redirect } from "next/navigation";

/**
 * L'ancien écran d'offre. Le paywall n'est plus une étape du parcours :
 * il se pose sur le tableau de bord. Les liens qui pointaient ici suivent.
 */
export default function OfferRedirect() {
  redirect("/app?offre=1");
}
