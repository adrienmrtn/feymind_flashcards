import { redirect } from "next/navigation";

/**
 * L'ancienne démo — dépose, fiche, cartes — a quitté le parcours.
 */
export default function RetiredDemoStep() {
  redirect("/commencer/ecole");
}
