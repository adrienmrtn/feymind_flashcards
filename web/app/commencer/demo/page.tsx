import { redirect } from "next/navigation";

/**
 * L'ancienne démo en trois temps a quitté le parcours.
 * Un ancien lien ne doit pas ouvrir un cul-de-sac.
 */
export default function RetiredDemoStep() {
  redirect("/commencer/ecole");
}
